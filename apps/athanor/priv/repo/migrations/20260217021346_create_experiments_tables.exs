defmodule Athanor.Repo.Migrations.CreateExperimentsTables do
  use Ecto.Migration

  def change do
    create table(:experiment_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :experiment_module, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :configuration, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create table(:experiment_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :instance_id, references(:experiment_instances, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:experiment_runs, [:instance_id])
    create index(:experiment_runs, [:status])

    create table(:run_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:experiment_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :map, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:run_results, [:run_id])
    create index(:run_results, [:run_id, :key])

    create table(:run_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:experiment_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :level, :string, null: false
      add :message, :text, null: false
      add :metadata, :map
      add :timestamp, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:run_logs, [:run_id])
    create index(:run_logs, [:run_id, :timestamp])
    create index(:run_logs, [:run_id, :level])
  end
end
