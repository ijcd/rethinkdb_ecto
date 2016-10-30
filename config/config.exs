use Mix.Config

config :rethinkdb_ecto, RethinkDB.EctoTest.Repo,
  adapter: RethinkDB.Ecto,
  database: 'test'
