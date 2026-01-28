defmodule TimeclockWeb.FlopConfig do
  def table_opts do
    [
      table_attrs: [class: "w-full border-collapse border border-slate-400"],
      thead_th_attrs: [class: "p-2 bg-gray-50 border border-slate-300"],
      tbody_td_attrs: [class: "p-2 border border-slate-300"]
    ]
  end

  def pagination_opts do
    [
      page_links: :hide,
      wrapper_attrs: [
        class: "text-center mt-4"
      ],
      previous_link_content: Phoenix.HTML.raw("← Previous"),
      previous_link_attrs: [
        class: "p-2 mr-2 border rounded border-slate-500"
      ],
      next_link_content: Phoenix.HTML.raw("Next →"),
      next_link_attrs: [
        class: "p-2 ml-2 border rounded border-slate-500"
      ]
    ]
  end
end
