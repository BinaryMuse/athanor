defmodule AthanorWeb.Experiments.Components.StatusBadge do
  @moduledoc """
  Status badge component for experiment runs.
  """

  use Phoenix.Component

  attr :status, :string, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={badge_class(@status)}>
      {String.capitalize(@status)}
    </span>
    """
  end

  defp badge_class("pending"), do: "badge badge-ghost"
  defp badge_class("running"), do: "badge badge-info animate-pulse"
  defp badge_class("completed"), do: "badge badge-success"
  defp badge_class("failed"), do: "badge badge-error"
  defp badge_class("cancelled"), do: "badge badge-warning"
  defp badge_class(_), do: "badge"
end
