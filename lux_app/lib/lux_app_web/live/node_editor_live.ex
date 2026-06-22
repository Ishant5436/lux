defmodule LuxAppWeb.NodeEditorLive do
  use LuxAppWeb, :live_view
  require Logger

  alias LuxApp.Repo
  alias LuxApp.Schemas.Agent
  alias LuxApp.Schemas.Prism
  alias LuxApp.Schemas.Lens
  alias LuxApp.Schemas.Beam
  alias LuxApp.Schemas.Edge

  @node_types %{
    "agent" => %{
      label: "Agent",
      description: "An autonomous agent that can perform tasks",
      color: "#4ade80"
    },
    "prism" => %{
      label: "Prism",
      description: "Processes and transforms data",
      color: "#60a5fa"
    },
    "lens" => %{
      label: "Lens",
      description: "Retrieves data from external sources",
      color: "#c084fc"
    },
    "beam" => %{
      label: "Beam",
      description: "Executes actions in external systems",
      color: "#fb923c"
    }
  }

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LuxApp.PubSub, "node_editor")
    end

    # Ensure Ultimate Assistant agent exists (for test capability and basic layout)
    ensure_ultimate_assistant_agent()

    # Load from DB
    agents = Repo.all(Agent) |> Enum.map(&map_node(&1, "agent"))
    prisms = Repo.all(Prism) |> Enum.map(&map_node(&1, "prism"))
    lenses = Repo.all(Lens) |> Enum.map(&map_node(&1, "lens"))
    beams = Repo.all(Beam) |> Enum.map(&map_node(&1, "beam"))

    nodes = agents ++ prisms ++ lenses ++ beams
    edges = Repo.all(Edge) |> Enum.map(&map_edge/1)

    {:ok,
     socket
     |> assign(:nodes, nodes)
     |> assign(:edges, edges)
     |> assign(:node_types, @node_types)
     |> assign(:selected_node, nil)
     |> assign(:selected_edge, nil)
     |> assign(:dragging_node, nil)
     |> assign(:drawing_edge, nil)}
  end

  defp ensure_ultimate_assistant_agent do
    if Enum.empty?(Repo.all(Agent)) do
      uuid = clean_uuid("agent-1")
      %Agent{}
      |> Agent.changeset(%{
        id: uuid,
        name: "Ultimate Assistant",
        description: "Tools Agent",
        goal: "Help users with various tasks",
        position_x: 400,
        position_y: 200
      })
      |> Repo.insert()
    end
  end

  # Node selection and canvas interaction
  def handle_event("node_selected", %{"node_id" => node_id}, socket) do
    uuid = clean_uuid(node_id)
    selected_node = Enum.find(socket.assigns.nodes, &(&1["id"] == uuid))

    # Broadcast selection to other clients
    Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_selected, uuid})

    {:noreply, socket |> assign(:selected_node, selected_node) |> assign(:selected_edge, nil)}
  end

  def handle_event("canvas_clicked", _params, socket) do
    Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:canvas_clicked})
    {:noreply, socket |> assign(:selected_node, nil) |> assign(:selected_edge, nil)}
  end

  # Node dragging and movement
  def handle_event("node_dragged", %{"node_id" => node_id, "x" => x, "y" => y}, socket) do
    uuid = clean_uuid(node_id)
    
    # Update position in DB
    update_node_position_in_db(uuid, x, y)

    nodes =
      Enum.map(socket.assigns.nodes, fn node ->
        if node["id"] == uuid do
          %{node | "position" => %{"x" => x, "y" => y}}
        else
          node
        end
      end)

    updated_node = Enum.find(nodes, &(&1["id"] == uuid))

    # Broadcast node update to other clients
    Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})

    {:noreply, assign(socket, :nodes, nodes)}
  end

  def handle_event("mousedown", %{"node_id" => node_id, "clientX" => x, "clientY" => y}, socket) do
    uuid = clean_uuid(node_id)
    node = Enum.find(socket.assigns.nodes, &(&1["id"] == uuid))
    original_position = node["position"]

    mouse_offset_x = x - original_position["x"]
    mouse_offset_y = y - original_position["y"]

    {:noreply,
     assign(socket, :dragging_node, %{
       "id" => uuid,
       "mouse_offset_x" => mouse_offset_x,
       "mouse_offset_y" => mouse_offset_y,
       "original_position" => original_position
     })}
  end

  def handle_event("mousemove", %{"clientX" => x, "clientY" => y}, socket) do
    case socket.assigns.dragging_node do
      %{
        "id" => uuid,
        "mouse_offset_x" => offset_x,
        "mouse_offset_y" => offset_y,
        "original_position" => _original_position
      } ->
        new_x = x - offset_x
        new_y = y - offset_y

        snapped_x = round(new_x / 20) * 20
        snapped_y = round(new_y / 20) * 20

        bounded_x = max(0, min(snapped_x, 1720))
        bounded_y = max(0, min(snapped_y, 980))

        # Update position in DB
        update_node_position_in_db(uuid, bounded_x, bounded_y)

        nodes =
          Enum.map(socket.assigns.nodes, fn
            %{"id" => ^uuid} = node ->
              %{node | "position" => %{"x" => bounded_x, "y" => bounded_y}}

            node ->
              node
          end)

        updated_node = Enum.find(nodes, &(&1["id"] == uuid))

        # Broadcast node update to other clients
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})

        {:noreply, assign(socket, :nodes, nodes)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("mouseup", _params, socket) do
    case socket.assigns.dragging_node do
      %{"id" => uuid} ->
        updated_node = Enum.find(socket.assigns.nodes, &(&1["id"] == uuid))
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})
      _ ->
        :ok
    end

    {:noreply, assign(socket, :dragging_node, nil)}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    case socket.assigns.dragging_node do
      %{"id" => uuid, "original_position" => original_position} ->
        update_node_position_in_db(uuid, original_position["x"], original_position["y"])

        nodes =
          Enum.map(socket.assigns.nodes, fn
            %{"id" => ^uuid} = node ->
              %{node | "position" => original_position}

            node ->
              node
          end)

        updated_node = Enum.find(nodes, &(&1["id"] == uuid))
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})

        {:noreply, socket |> assign(:nodes, nodes) |> assign(:dragging_node, nil)}

      _ ->
        {:noreply, socket}
    end
  end

  # Edge handling
  def handle_event("edge_started", %{"source_id" => source_id}, socket) do
    uuid = clean_uuid(source_id)
    {:noreply, assign(socket, :drawing_edge, %{"source_id" => uuid})}
  end

  def handle_event("edge_completed", %{"target_id" => target_id}, socket) do
    target_uuid = clean_uuid(target_id)
    case socket.assigns.drawing_edge do
      %{"source_id" => source_uuid} when not is_nil(source_uuid) ->
        edge_id = "edge-#{source_uuid}-#{target_uuid}"
        edge_uuid = clean_uuid(edge_id)

        existing_edge = Enum.find(socket.assigns.edges, fn edge -> edge["id"] == edge_id end)

        if existing_edge do
          {:noreply, socket |> assign(:drawing_edge, nil)}
        else
          source_node = Enum.find(socket.assigns.nodes, &(&1["id"] == source_uuid))
          target_node = Enum.find(socket.assigns.nodes, &(&1["id"] == target_uuid))

          if source_node && target_node do
            edge_attrs = %{
              id: edge_uuid,
              source_id: source_uuid,
              source_type: source_node["type"],
              target_id: target_uuid,
              target_type: target_node["type"]
            }

            case Repo.insert(%Edge{} |> Edge.changeset(edge_attrs)) do
              {:ok, edge} ->
                mapped = map_edge(edge)
                Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:edge_created, mapped})
                {:noreply, socket |> assign(:edges, [mapped | socket.assigns.edges]) |> assign(:drawing_edge, nil)}

              {:error, changeset} ->
                Logger.error("Failed to insert edge: #{inspect(changeset)}")
                {:noreply, assign(socket, :drawing_edge, nil)}
            end
          else
            {:noreply, socket |> assign(:drawing_edge, nil)}
          end
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edge_cancelled", _params, socket) do
    {:noreply, assign(socket, :drawing_edge, nil)}
  end

  def handle_event("edge_selected", %{"edge_id" => edge_id}, socket) do
    selected_edge = Enum.find(socket.assigns.edges, &(&1["id"] == edge_id))
    Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:edge_selected, edge_id})
    {:noreply, socket |> assign(:selected_edge, selected_edge) |> assign(:selected_node, nil)}
  end

  def handle_event("delete_edge", _params, socket) do
    if socket.assigns.selected_edge do
      edge_id = socket.assigns.selected_edge["id"]
      uuid = clean_uuid(edge_id)
      
      case Repo.get(Edge, uuid) do
        nil -> :ok
        edge -> Repo.delete!(edge)
      end
      
      edges = Enum.reject(socket.assigns.edges, &(&1["id"] == edge_id))
      
      Phoenix.PubSub.broadcast(LuxApp.PubSub, "node_editor", {:edge_removed, edge_id})
      
      {:noreply, socket |> assign(:edges, edges) |> assign(:selected_edge, nil)}
    else
      {:noreply, socket}
    end
  end

  # Node management
  def handle_event("node_added", %{"node" => node}, socket) do
    type = node["type"]
    uuid = clean_uuid(node["id"])
    x = node["position"]["x"]
    y = node["position"]["y"]
    data = node["data"]

    case create_db_node(uuid, type, x, y, data) do
      {:ok, entity} ->
        mapped = map_node(entity, type)
        nodes = [mapped | socket.assigns.nodes]
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_added, mapped})
        {:noreply, assign(socket, :nodes, nodes)}

      {:error, changeset} ->
        Logger.error("Failed to add node: #{inspect(changeset)}")
        {:noreply, socket}
    end
  end

  def handle_event("node_removed", %{"id" => node_id}, socket) do
    uuid = clean_uuid(node_id)
    case Enum.find(socket.assigns.nodes, &(&1["id"] == uuid)) do
      nil ->
        {:noreply, socket}

      node ->
        delete_db_node(uuid, node["type"])

        # Also delete all connected edges in the DB
        edges_to_delete = Enum.filter(socket.assigns.edges, &(&1["source"] == uuid or &1["target"] == uuid))
        Enum.each(edges_to_delete, fn edge ->
          edge_uuid = clean_uuid(edge["id"])
          case Repo.get(Edge, edge_uuid) do
            nil -> :ok
            struct -> Repo.delete(struct)
          end
        end)

        nodes = Enum.reject(socket.assigns.nodes, &(&1["id"] == uuid))
        edges = Enum.reject(socket.assigns.edges, &(&1["source"] == uuid or &1["target"] == uuid))
        
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_removed, uuid})

        selected_node = if socket.assigns.selected_node && socket.assigns.selected_node["id"] == uuid, do: nil, else: socket.assigns.selected_node

        {:noreply, socket |> assign(:nodes, nodes) |> assign(:edges, edges) |> assign(:selected_node, selected_node)}
    end
  end

  def handle_event("update_node", %{"node" => node_params}, socket) do
    uuid = clean_uuid(node_params["id"])
    case Enum.find(socket.assigns.nodes, &(&1["id"] == uuid)) do
      nil ->
        {:noreply, socket}

      node ->
        update_db_node_properties(uuid, node["type"], node_params["data"])

        nodes =
          Enum.map(socket.assigns.nodes, fn n ->
            if n["id"] == uuid do
              %{n | "data" => Map.merge(n["data"], node_params["data"])}
            else
              n
            end
          end)

        updated_node = Enum.find(nodes, &(&1["id"] == uuid))
        Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})

        selected_node = Enum.find(nodes, &(&1["id"] == uuid))
        {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node)}
    end
  end

  def handle_event(
        "update_property",
        %{"key" => "Enter", "value" => value, "field" => field} = params,
        socket
      ) do
    if (params["metaKey"] == true or params["ctrlKey"] == true) and socket.assigns.selected_node do
      uuid = clean_uuid(socket.assigns.selected_node["id"])
      
      case Enum.find(socket.assigns.nodes, &(&1["id"] == uuid)) do
        nil ->
          {:noreply, socket}

        node ->
          new_data = Map.put(node["data"], field, value)
          update_db_node_properties(uuid, node["type"], new_data)

          nodes =
            Enum.map(socket.assigns.nodes, fn
              %{"id" => ^uuid} = n ->
                put_in(n, ["data", field], value)

              n ->
                n
            end)

          updated_node = Enum.find(nodes, &(&1["id"] == uuid))
          Phoenix.PubSub.broadcast_from(LuxApp.PubSub, self(), "node_editor", {:node_updated, uuid, updated_node})

          selected_node = Enum.find(nodes, &(&1["id"] == uuid))
          {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_property", _params, socket) do
    {:noreply, socket}
  end

  # PubSub Broadcast Handlers
  def handle_info({:node_added, node}, socket) do
    nodes = if Enum.any?(socket.assigns.nodes, &(&1["id"] == node["id"])), do: socket.assigns.nodes, else: [node | socket.assigns.nodes]
    {:noreply, socket |> assign(:nodes, nodes) |> push_event("node_added", %{node: node})}
  end

  def handle_info({:node_removed, node_id}, socket) do
    nodes = Enum.reject(socket.assigns.nodes, &(&1["id"] == node_id))
    selected_node = if socket.assigns.selected_node && socket.assigns.selected_node["id"] == node_id, do: nil, else: socket.assigns.selected_node
    edges = Enum.reject(socket.assigns.edges, &(&1["source"] == node_id or &1["target"] == node_id))
    {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node) |> assign(:edges, edges) |> push_event("node_removed", %{node_id: node_id})}
  end

  def handle_info({:node_updated, node_id, updated_node}, socket) do
    nodes = Enum.map(socket.assigns.nodes, fn node ->
      if node["id"] == node_id, do: updated_node, else: node
    end)
    selected_node = if socket.assigns.selected_node && socket.assigns.selected_node["id"] == node_id, do: updated_node, else: socket.assigns.selected_node
    {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node) |> push_event("node_updated", %{node: updated_node})}
  end

  def handle_info({:edge_created, edge}, socket) do
    edges = if Enum.any?(socket.assigns.edges, &(&1["id"] == edge["id"])), do: socket.assigns.edges, else: [edge | socket.assigns.edges]
    {:noreply, socket |> assign(:edges, edges) |> push_event("edge_created", %{edge: edge})}
  end

  def handle_info({:edge_removed, edge_id}, socket) do
    edges = Enum.reject(socket.assigns.edges, &(&1["id"] == edge_id))
    selected_edge = if socket.assigns.selected_edge && socket.assigns.selected_edge["id"] == edge_id, do: nil, else: socket.assigns.selected_edge
    {:noreply, socket |> assign(:edges, edges) |> assign(:selected_edge, selected_edge) |> push_event("edge_removed", %{edge_id: edge_id})}
  end

  def handle_info({:node_selected, node_id}, socket) do
    {:noreply, socket |> push_event("node_selected", %{node_id: node_id})}
  end

  def handle_info({:canvas_clicked}, socket) do
    {:noreply, socket |> push_event("canvas_clicked", %{})}
  end

  def handle_info({:edge_selected, edge_id}, socket) do
    {:noreply, socket |> push_event("edge_selected", %{edge_id: edge_id})}
  end

  # Helper Functions
  def clean_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        uuid

      :error ->
        hash = :crypto.hash(:md5, id) |> Base.encode16(case: :lower)
        String.slice(hash, 0..7) <> "-" <>
        String.slice(hash, 8..11) <> "-" <>
        "4" <> String.slice(hash, 13..15) <> "-" <>
        "8" <> String.slice(hash, 17..19) <> "-" <>
        String.slice(hash, 20..31)
    end
  end

  defp get_schema_module("agent"), do: Agent
  defp get_schema_module("prism"), do: Prism
  defp get_schema_module("lens"), do: Lens
  defp get_schema_module("beam"), do: Beam

  defp map_node(entity, "agent") do
    %{
      "id" => entity.id,
      "type" => "agent",
      "position" => %{"x" => entity.position_x || 0, "y" => entity.position_y || 0},
      "data" => %{
        "label" => entity.name,
        "description" => entity.description || "",
        "goal" => entity.goal || "",
        "components" => []
      }
    }
  end

  defp map_node(entity, type) do
    %{
      "id" => entity.id,
      "type" => type,
      "position" => %{"x" => entity.position_x || 0, "y" => entity.position_y || 0},
      "data" => %{
        "label" => entity.name,
        "description" => entity.description || ""
      }
    }
  end

  defp map_edge(edge) do
    %{
      "id" => "edge-#{edge.source_id}-#{edge.target_id}",
      "source" => edge.source_id,
      "target" => edge.target_id,
      "type" => "signal"
    }
  end

  defp create_db_node(uuid, type, x, y, data) do
    mod = get_schema_module(type)
    attrs = %{
      id: uuid,
      name: data["label"] || "New " <> String.capitalize(type),
      description: data["description"] || "",
      position_x: x,
      position_y: y
    }
    
    attrs = if type == "agent", do: Map.put(attrs, :goal, data["goal"] || ""), else: attrs
    
    struct(mod, %{})
    |> mod.changeset(attrs)
    |> Repo.insert()
  end

  defp update_node_position_in_db(uuid, x, y) do
    # Try finding node in all four tables
    cond do
      entity = Repo.get(Agent, uuid) -> entity |> Agent.changeset(%{position_x: x, position_y: y}) |> Repo.update()
      entity = Repo.get(Prism, uuid) -> entity |> Prism.changeset(%{position_x: x, position_y: y}) |> Repo.update()
      entity = Repo.get(Lens, uuid)  -> entity |> Lens.changeset(%{position_x: x, position_y: y})  |> Repo.update()
      entity = Repo.get(Beam, uuid)  -> entity |> Beam.changeset(%{position_x: x, position_y: y})  |> Repo.update()
      true -> {:error, :not_found}
    end
  end

  defp update_db_node_properties(uuid, type, data) do
    mod = get_schema_module(type)
    case Repo.get(mod, uuid) do
      nil -> {:error, :not_found}
      entity ->
        attrs = %{
          name: data["label"],
          description: data["description"]
        }
        attrs = if type == "agent", do: Map.put(attrs, :goal, data["goal"]), else: attrs
        
        entity
        |> mod.changeset(attrs)
        |> Repo.update()
    end
  end

  defp delete_db_node(uuid, type) do
    mod = get_schema_module(type)
    case Repo.get(mod, uuid) do
      nil -> {:error, :not_found}
      entity -> Repo.delete(entity)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen bg-gray-900 text-white overflow-hidden">
      <!-- Component Palette -->
      <div class="w-64 border-r border-gray-700 p-4 overflow-y-auto">
        <h2 class="text-xl font-bold mb-4">Components</h2>
        <div class="space-y-2">
          <%= for {type, info} <- @node_types do %>
            <div
              class="p-3 bg-gray-800 rounded-md cursor-move border border-gray-700 hover:border-blue-500 transition-colors"
              draggable="true"
              phx-hook="DraggableNode"
              id={"draggable-#{type}"}
              data-type={type}
            >
              <div class="flex items-center">
                <div
                  class="w-8 h-8 rounded-full mr-2 flex items-center justify-center"
                  style={"background: #{info.color}20"}
                >
                  <div class="w-5 h-5" style={"background: #{info.color}"}></div>
                </div>
                <div>
                  <div class="font-medium">{info.label}</div>
                  <div class="text-xs text-gray-400">{info.description}</div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Node Editor Canvas -->
      <div
        class="flex-1 relative"
        id="node-editor-canvas"
        phx-hook="NodeCanvas"
        phx-click="canvas_clicked"
      >
        <svg class="w-full h-full absolute inset-0">
          <!-- Grid Background -->
          <defs>
            <pattern id="grid" width="16" height="16" patternUnits="userSpaceOnUse">
              <path d="M 16 0 L 0 0 0 16" fill="none" stroke="#333" stroke-width="0.5" />
            </pattern>
            
            <!-- Glow filters for nodes and ports -->
            <filter id="glow-selected" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="5" result="blur" />
              <feFlood flood-color="#fff" flood-opacity="0.3" result="color" />
              <feComposite in="color" in2="blur" operator="in" result="glow" />
              <feComposite in="glow" in2="SourceGraphic" operator="over" />
            </filter>

            <filter id="glow-hover" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="3" result="blur" />
              <feFlood flood-color="#fff" flood-opacity="0.2" result="color" />
              <feComposite in="color" in2="blur" operator="in" result="glow" />
              <feComposite in="glow" in2="SourceGraphic" operator="over" />
            </filter>

            <filter id="port-glow" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feFlood flood-color="#fff" flood-opacity="0.5" result="color" />
              <feComposite in="color" in2="blur" operator="in" result="glow" />
              <feComposite in="glow" in2="SourceGraphic" operator="over" />
            </filter>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
          
          <!-- Edges -->
          <%= for edge <- @edges do %>
            <g class={"edge #{if @selected_edge && @selected_edge["id"] == edge["id"], do: "selected-edge", else: ""}"}>
              <path
                class={"edge-path #{if @selected_edge && @selected_edge["id"] == edge["id"], do: "selected-edge", else: ""}"}
                data-edge-id={edge["id"]}
                data-source={edge["source"]}
                data-target={edge["target"]}
                stroke={if @selected_edge && @selected_edge["id"] == edge["id"], do: "#3b82f6", else: "#666"}
                stroke-width={if @selected_edge && @selected_edge["id"] == edge["id"], do: "3", else: "2"}
                fill="none"
                phx-click="edge_selected"
                phx-value-edge_id={edge["id"]}
                style="cursor: pointer;"
              />
            </g>
          <% end %>
          
          <!-- Drawing Edge (if any) -->
          <%= if @drawing_edge do %>
            <path id="drawing-edge" stroke="#666" stroke-width="2" stroke-dasharray="5,5" fill="none" />
          <% end %>
          
          <!-- Nodes -->
          <%= for node <- @nodes do %>
            <g
              class={"node #{if @selected_node && @selected_node["id"] == node["id"], do: "selected", else: ""}"}
              transform={"translate(#{node["position"]["x"]},#{node["position"]["y"]})"}
              phx-click="node_selected"
              phx-value-node_id={node["id"]}
              data-node-id={node["id"]}
              phx-hook="NodeDraggable"
              id={"node-#{node["id"]}"}
            >
              <!-- Glow effect for selected node (only visible when selected) -->
              <rect
                class="node-glow"
                width="210"
                height="110"
                x="-5"
                y="-5"
                rx="10"
                ry="10"
                fill="none"
                stroke={@node_types[node["type"]].color}
                stroke-width="3"
                filter="url(#glow-selected)"
                style={"opacity: #{if @selected_node && @selected_node["id"] == node["id"], do: "1", else: "0"}"}
              />
              
              <!-- Main node rectangle -->
              <rect
                class="node-body"
                width="200"
                height="100"
                rx="5"
                ry="5"
                fill={@node_types[node["type"]].color <> "20"}
                stroke={@node_types[node["type"]].color}
                stroke-width="2"
              />
              <text x="10" y="30" fill="white" font-weight="bold">{node["data"]["label"]}</text>
              <text x="10" y="50" fill="#999" font-size="12">{node["data"]["description"]}</text>
              
              <!-- Node Ports -->
              <circle class="port input" cx="0" cy="50" r="5" fill={@node_types[node["type"]].color} />
              <circle
                class="port output"
                cx="200"
                cy="50"
                r="5"
                fill={@node_types[node["type"]].color}
              />
            </g>
          <% end %>
        </svg>
      </div>
      
      <!-- Properties Panel -->
      <div class="w-64 border-l border-gray-700 p-4 overflow-y-auto">
        <h2 class="text-xl font-bold mb-4">Properties</h2>
        <%= if @selected_node do %>
          <form phx-submit="update_node">
            <input type="hidden" name="node[id]" value={@selected_node["id"]} />
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">Name</label>
                <input
                  type="text"
                  name="node[data][label]"
                  value={@selected_node["data"]["label"]}
                  class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                  phx-keydown="update_property"
                  phx-value-field="label"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">Description</label>
                <textarea
                  name="node[data][description]"
                  class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                  rows="3"
                  phx-keydown="update_property"
                  phx-value-field="description"
                ><%= @selected_node["data"]["description"] %></textarea>
              </div>
              <%= if @selected_node["type"] == "agent" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1">Goal</label>
                  <textarea
                    name="node[data][goal]"
                    class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                    rows="3"
                    phx-keydown="update_property"
                    phx-value-field="goal"
                  ><%= @selected_node["data"]["goal"] %></textarea>
                </div>
              <% end %>
              <button
                type="submit"
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md"
              >
                Update
              </button>
            </div>
          </form>
        <% else %>
          <%= if @selected_edge do %>
            <%
              source_node = Enum.find(@nodes, &(&1["id"] == @selected_edge["source"]))
              target_node = Enum.find(@nodes, &(&1["id"] == @selected_edge["target"]))
              source_name = if source_node, do: source_node["data"]["label"], else: @selected_edge["source"]
              target_name = if target_node, do: target_node["data"]["label"], else: @selected_edge["target"]
            %>
            <div>
              <h3 class="text-lg font-semibold mb-2">Edge Properties</h3>
              <p class="text-sm text-gray-400 mb-2">Connection between nodes.</p>
              <div class="space-y-4 mt-4">
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1">Source: <%= source_name %></label>
                  <div class="bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-xs truncate">
                    <%= @selected_edge["source"] %>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1">Target: <%= target_name %></label>
                  <div class="bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-xs truncate">
                    <%= @selected_edge["target"] %>
                  </div>
                </div>
                <button
                  id="delete-edge-button"
                  phx-click="delete_edge"
                  class="w-full bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-md"
                >
                  Delete Edge
                </button>
              </div>
            </div>
          <% else %>
            <div class="text-gray-400 text-sm">
              Select a node or edge to view and edit its properties.
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
