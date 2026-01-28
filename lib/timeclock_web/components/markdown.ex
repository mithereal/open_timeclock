defmodule TimeclockWeb.Components.Markdown do
  use Phoenix.Component

  attr :text, :string, required: true, doc: "Markdown Document"

  def markdown(assigns) do
    text = if assigns.text == nil, do: "", else: assigns.text

    markdown_html =
      String.trim(text)
      |> Earmark.as_html!(code_class_prefix: "lang- language-")
      |> Phoenix.HTML.raw()

    assigns = assign(assigns, :markdown, markdown_html)

    ~H"""
    {@markdown}
    """
  end
end
