defmodule TimeclockWeb.UploadComponent do
  use TimeclockWeb, :live_component
  alias Timeclock.Images

  @impl true
  def mount(socket) do
    case System.get_env("AWS_ACCESS_KEY_ID") do
      nil ->
        {:ok,
         socket
         |> assign(target: nil)
         |> assign(upload_component_file: nil)
         |> allow_upload(:upload_component_file,
           accept: ["image/jpeg", "image/png", "image/gif"],
           max_entries: 1,
           max_file_size: 15_000_000
         )}

      _ ->
        {:ok,
         socket
         |> assign(target: nil)
         |> assign(upload_component_file: nil)
         |> allow_upload(:upload_component_file,
           accept: ["image/jpeg", "image/png", "image/gif"],
           max_entries: 1,
           max_file_size: 15_000_000,
           external: &presign_upload/2
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form
      id={"#{@id}-upload-form"}
      class="flex flex-col gap-4 items-center"
      action="#"
      phx-change="validate"
      phx-submit="save"
      phx-drop-target={@uploads.upload_component_file.ref}
      phx-target={@myself}
    >
      <div class="p-2 ml-4 border-2 border-neutral-300 border-dashed rounded-lg">
        <div class={[if(Enum.count(@uploads.upload_component_file.entries) > 0, do: "hidden")]}>
          <.live_file_input upload={@uploads.upload_component_file} />
        </div>
        <div :for={entry <- @uploads.upload_component_file.entries} class="flex justify-around">
          <div>
            <div class="text-right pr-1">
              <a
                href="#"
                phx-click="cancel"
                phx-target={@myself}
                phx-value-ref={entry.ref}
                class="upload-entry__cancel text-left"
              >
                &times;
              </a>
            </div>
            <.live_img_preview class="max-h-64" entry={entry} height="120" />
            <div>{entry.progress}%</div>
          </div>
        </div>
      </div>
      <div>
        <.button>Upload</.button>
      </div>
      <.input field="property_id" type="hidden" name="property_id" value={@target} />
      <.input field="type" type="hidden" name="type" value={@type} />
    </form>
    """
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :upload_component_file, ref)}
  end

  def handle_event("save", _, socket) do
    target_id = socket.assigns.target

    type =
      socket.assigns.type || "main"

    thumbnail_sizes = Timeclock.config([:thumbnail_sizes])

    image =
      consume_uploaded_entries(socket, :upload_component_file, fn %{path: path}, _entry ->
        dest_filename = Path.basename(path) |> String.replace("live_view_upload-", "")

        dest =
          Path.join([
            :code.priv_dir(Timeclock),
            "static",
            "images",
            "uploads",
            dest_filename
          ])

        File.cp!(path, dest)
        file = File.read!(dest)

        filepath =
          "/" <>
            Path.join([
              "images",
              "uploads",
              dest_filename
            ])

        {_, %{image: image}} = Images.create_image(%{link: filepath, filepath: filepath})

        case type do
          _ ->
            image
        end

        for {x, y} <- thumbnail_sizes do
          {:ok, file_data} = Thumbp.create(file, x, y)
          ext = "-#{x}x#{y}.webp"
          web_path = dest <> ext
          File.write!(web_path, file_data)

          filepath =
            "/" <>
              Path.join([
                "images",
                "uploads",
                dest_filename <> ext
              ])

          Images.create_image(%{link: filepath, filepath: filepath})
        end

        {:ok, ~p"/images/uploads/#{Path.basename(dest)}"}
      end)

    send(self(), :refresh)

    {:noreply, assign(socket, image: List.first(image))}
  end

  import Maybe

  def presign_upload(entry, socket) do
    bin = Nanoid.generate()
    [default_bucket | _] = TimeclockWeb.Endpoint.host() |> String.split([".", ":"])

    bucket =
      case maybe(socket.bucket) do
        nil -> Application.get_env(Timeclock, :custom_bucket, default_bucket)
        bucket -> bucket
      end

    s3_options = [
      key: "images/uploads/#{Base.url_encode64(bin)}/#{entry.client_name}",
      bucket: bucket
    ]

    form =
      ReqS3.presign_form(
        [
          content_type: entry.client_type,
          max_size: 15_000_000
        ] ++ s3_options
      )

    meta = %{uploader: "S3", key: s3_options[:key], url: form.url, fields: Map.new(form.fields)}
    {:ok, meta, socket}
  end
end
