defmodule App do
    use Application
    use RethinkDB.Connection
    import RethinkDB.Query
    import Supervisor.Spec, warn: false
    import RethinkDB.Lambda
    alias RethinkDB.Query

    
    worker(App, [])

    def calc_weighted_value(events) do
        half_life = 24
        interval = 12
        percentage = 0.99
        decay = :math.pow(percentage, half_life / interval)

        Query.update(events, (lambda fn(row) ->
                %{
                    weighted_value: Query.mul(row[:weighted_value], decay)
                }
            end)
        )
    end

    def start_job do
        #    * * * * * command to be executed
        #    - - - - -
        #    | | | | |
        #    | | | | ----- Day of week (0 - 7) (Sunday=0 or 7)
        #    | | | ------- Month (1 - 12)
        #    | | --------- Day of month (1 - 31)
        #    | ----------- Hour (0 - 23)
        #    ------------- Minute (0 - 59)
        job = %Quantum.Job{
            schedule: "*/15 * * * *", # Once every hour
            task: fn -> start end
        }
        Quantum.add_job(:ticker, job)
    end

    def start do
        IO.puts "Running Quantum Job, reducing weighted_ratio of all events"

        ip_address_docker_cloud = System.get_env("RETHINKDB_PORT_8080_TCP_ADDR")
        rethinkdb_auth_key = System.get_env("RETHINKDB_AUTH_KEY")

        { :ok, conn } = cond do
            !is_nil(ip_address_docker_cloud) ->
                 RethinkDB.Connection.start_link(
                    [
                        host: ip_address_docker_cloud
                    ]
                )

            !is_nil(rethinkdb_auth_key) ->
                RethinkDB.Connection.start_link(
                    [
                        port: 28015,
                        db: "prod",
                        host: "localhost",
                        auth_key: rethinkdb_auth_key
                    ]
                )

            true ->
                RethinkDB.Connection.start_link([])
        end

        table("events")
            |> calc_weighted_value
            |> RethinkDB.run(conn)
    end

end
