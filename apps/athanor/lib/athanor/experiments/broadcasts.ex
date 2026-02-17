defmodule Athanor.Experiments.Broadcasts do
  @moduledoc """
  Centralized PubSub broadcasts for experiment events.
  """

  alias Phoenix.PubSub

  @pubsub Athanor.PubSub

  # --- Instance Events ---

  def instance_created(instance) do
    PubSub.broadcast(@pubsub, "experiments:instances", {:instance_created, instance})
  end

  def instance_updated(instance) do
    PubSub.broadcast(@pubsub, "experiments:instances", {:instance_updated, instance})
    PubSub.broadcast(@pubsub, "experiments:instance:#{instance.id}", {:instance_updated, instance})
  end

  def instance_deleted(instance) do
    PubSub.broadcast(@pubsub, "experiments:instances", {:instance_deleted, instance})
  end

  # --- Run Events ---

  def run_created(run) do
    PubSub.broadcast(@pubsub, "experiments:instance:#{run.instance_id}", {:run_created, run})
  end

  def run_updated(run) do
    PubSub.broadcast(@pubsub, "experiments:instance:#{run.instance_id}", {:run_updated, run})
    PubSub.broadcast(@pubsub, "experiments:run:#{run.id}", {:run_updated, run})
  end

  def run_started(run) do
    run_updated(run)
    PubSub.broadcast(@pubsub, "experiments:runs:active", {:run_started, run})
  end

  def run_completed(run) do
    run_updated(run)
    PubSub.broadcast(@pubsub, "experiments:runs:active", {:run_completed, run})
  end

  # --- Log Events ---

  def log_added(run_id, log) do
    PubSub.broadcast(@pubsub, "experiments:run:#{run_id}", {:log_added, log})
  end

  def logs_added(run_id, count) do
    PubSub.broadcast(@pubsub, "experiments:run:#{run_id}", {:logs_added, count})
  end

  # --- Result Events ---

  def result_added(run_id, result) do
    PubSub.broadcast(@pubsub, "experiments:run:#{run_id}", {:result_added, result})
  end

  def results_added(run_id, count) do
    PubSub.broadcast(@pubsub, "experiments:run:#{run_id}", {:results_added, count})
  end

  # --- Progress Events ---

  def progress_updated(run_id, progress) do
    PubSub.broadcast(@pubsub, "experiments:run:#{run_id}", {:progress_updated, progress})
  end
end
