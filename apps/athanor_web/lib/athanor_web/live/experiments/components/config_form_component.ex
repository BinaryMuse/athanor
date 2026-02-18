defmodule AthanorWeb.Experiments.Components.ConfigFormComponent do
  use Phoenix.Component

  attr :schema_json, :string, required: true

  def config_form(assigns) do
    ~H"""
    <div
      id="config-form-hook"
      phx-hook="ConfigFormHook"
      data-schema={@schema_json}
      phx-update="ignore"
    >
      <input type="hidden" name="instance[configuration_json]" id="config-json-input" />
      <%!-- Hook renders all form fields dynamically --%>
    </div>
    """
  end
end
