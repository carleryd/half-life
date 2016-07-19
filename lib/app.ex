defmodule App do
    use RethinkDB.Connection
    import RethinkDB.Query
    import Supervisor.Spec, warn: false
    import RethinkDB.Lambda
    alias RethinkDB.Query

    worker(App, [])

    def calc_weighted_value(events) do
        hour = 3600
        half_life = 24 * hour

        # weighted_value * (1 - 0.5 * ((now - created_at) / half_life))
        # When (now - created_at) is half_life(i.e. 1 day has passed), it
        # becomes: weighted_value * (1 - 0.5 * 1)
        Query.update(events, (lambda fn(row) ->
                %{
                    weighted_value:
                        Query.mul(row[:weighted_value],
                            Query.sub(1,
                                Query.mul(0.5,
                                    Query.divide(
                                        Query.sub(
                                            Query.now
                                                |> Query.to_epoch_time,
                                            row[:created_at]
                                                |> Query.iso8601
                                                |> Query.to_epoch_time
                                        ),
                                        half_life
                                    )
                                )
                            )
                        )
                }
            end)
        )
    end

    def run do
        { :ok, conn } = RethinkDB.Connection.start_link(
            [ host: "localhost", port: 28015 ]
        )

        table("events")
            |> calc_weighted_value
            |> RethinkDB.run(conn)
            |> Utils.handle_graphql_resp
    end

end
