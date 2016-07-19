defmodule App do
    use RethinkDB.Connection
    import RethinkDB.Query
    import Supervisor.Spec, warn: false
    import RethinkDB.Lambda
    alias RethinkDB.Query

    worker(App, [])

    half_life = 24
    update_interval = 6
    percentage = 5


    def run do
        { :ok, conn } = RethinkDB.Connection.start_link(
            [ host: "localhost", port: 28015 ]
        )

        events_data = table("events")
            |> Query.map((lambda fn(row) ->
                    %{
                        created_at: (row[:created_at]
                            |> Query.iso8601
                            |> Query.to_epoch_time),
                        current_time: Query.now |> Query.to_epoch_time(),
                        popularity_value: row[:popularity_value],
                        weighted_value: row[:weighted_value],
                    }
                end)
            )
            |> RethinkDB.run(conn)
            |> Utils.handle_graphql_resp
            |> IO.inspect

        Enum.map(events_data,
            fn event_data ->
                IO.inspect event_data
                calculate(event_data)
            end
        )

    end

    def calculate event_data do
        event_data[:current_time] - event_data[:created_at]
    end

end
