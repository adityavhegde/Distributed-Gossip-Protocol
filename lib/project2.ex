defmodule GossipSpread do
  @interval 1
  def rumor(neighbors_list, counter, master, procId) do
    cond do
      #stop the process when counter reaches 10
      counter >= 10 ->
        IO.puts "<plotty: inactive, #{procId}>"
        exit(:shutdown)
    #otherwise wait for gossip or neighbors list
      true ->
        receive do
          :gossip ->
            case counter do
              #got the rumor for the first time
              0 ->
                IO.puts "<plotty: infected, #{procId}>"
                send master, :informed
              _ ->
                true
            end
            cond do
              #check if this node even knows the gossip
              Enum.count(neighbors_list)!=0->
                selectedNeighbor = neighbors_list |> Enum.random
                cond do
                  Process.alive?(selectedNeighbor) ->
                    send selectedNeighbor, :gossip
                    GossipSpread.rumor(neighbors_list, counter+1, master, procId)
                true ->
                  List.delete(neighbors_list, selectedNeighbor)
                  |> GossipSpread.rumor(counter+1, master, procId)
                end
              true ->
                GossipSpread.rumor(neighbors_list, counter+1, master, procId)
            end
          updated_neighbors_list ->
            GossipSpread.rumor(updated_neighbors_list, counter, master, procId)
        after 
          @interval ->
            cond do
              #check if this node even knows the gossip, select a random neighbor if true, and forward the gossip
              counter > 0 and Enum.count(neighbors_list)!=0->
                selectedNeighbor = neighbors_list |> Enum.random
                cond do
                  Process.alive?(selectedNeighbor) ->
                    send selectedNeighbor, :gossip
                    GossipSpread.rumor(neighbors_list, counter, master, procId)
                  true ->
                    List.delete(neighbors_list, selectedNeighbor)
                    |> GossipSpread.rumor(counter, master, procId)
                end
              true ->
                GossipSpread.rumor(neighbors_list, counter, master, procId)
            end
        end
    end
  end
end

defmodule Gossip do

  def lineTopology(nodesList) do
    numNodes = tuple_size(nodesList)
    #IO.inspect Process.registered()
    #no need to re-arrange nodesList
    Enum.each(0..numNodes-1, fn(i) ->
      #send list of neighbors of every ith to the ith node
      neighbors_i = []
      neighbors_i = cond do
       (i-1) >= 0 ->
          neighbors_i ++ [nodesList |> elem(i-1)]
        true ->
          neighbors_i ++ [nodesList |> elem(numNodes-1)]
      end
      neighbors_i = cond do
        (i+1) <numNodes ->
          neighbors_i ++ [nodesList |> elem(i+1)]
        true ->
          neighbors_i ++ [nodesList |> elem(0)]
      end
      #IO.inspect neighbors_i
      currentNode = nodesList |> elem(i)
      send currentNode, neighbors_i
    end)
    b = :os.system_time(:milli_seconds)
    send nodesList |> elem(0), :gossip
    Gossip.checkConvergence(numNodes, b)
  end

  def grid2DTopology(nodesList) do
    numNodes = tuple_size(nodesList)
    side = :math.sqrt(tuple_size(nodesList)) |> round
    list2d = Gossip.segment(nodesList, {}, {}, 0, side)
    Enum.each(0..side-1, fn(i) -> 
      Enum.each(0..side-1, fn(j) ->
        neighbors_ij = []
        neighbors_ij = cond do
          i-1 >= 0 ->
            neighbors_ij ++ [list2d |> elem(i-1) |> elem(j)]
          true ->
            neighbors_ij ++ [list2d |> elem(side-1) |> elem(j)]
        end 
        neighbors_ij = cond do
          i+1 < side ->
            neighbors_ij ++ [list2d |> elem(i+1) |> elem(j)]
          true -> 
            neighbors_ij ++ [list2d |> elem(0) |> elem(j)]
        end 
        neighbors_ij = cond do
          j-1 >= 0 ->
            neighbors_ij ++ [list2d |> elem(i) |> elem(j-1)]
          true -> 
            neighbors_ij ++ [list2d |> elem(i) |> elem(side-1)]
        end
        neighbors_ij = cond do
          j + 1 < side ->
            neighbors_ij ++ [list2d |> elem(i) |> elem(j+1)]
          true ->
            neighbors_ij ++ [list2d |> elem(i) |> elem(0)]
        end
          send list2d |> elem(i) |> elem(j), neighbors_ij   
      end)
    end)

    b = :os.system_time(:milli_seconds)
    send list2d |> elem(0) |> elem(0), :gossip 
    Gossip.checkConvergence(numNodes, b)
    
  end

  def gridImpTopology(nodesList) do
  
  end

  def fullTopology(nodesList) do
    numNodes = tuple_size(nodesList)
    Enum.each(0..numNodes-1, fn(i) -> 
      #send this nodes all the nodes other than itself, as neighbors
      send nodesList |> elem(i), Tuple.to_list(nodesList) -- [elem(nodesList, i)]
    end) 
    send nodesList |> elem(0), :gossip
    b = :os.system_time(:milli_seconds)
    Gossip.checkConvergence(numNodes, b)
  end

  # takes args of num of processes to be created and returns a list of process ids
  def createProcesses(numNodes) do
    nodesList = {}
    Gossip.createProcesses(numNodes, nodesList)
  end
  def createProcesses(0, nodesList) do
    nodesList
  end
  def createProcesses(numNodes, nodesList) do
    worker = Node.self() |> Node.spawn(GossipSpread, :rumor, [[], 0, self(), numNodes])
    #Process.register worker, String.to_atom("NodeNew"<>"#{numNodes}")
    nodesList = Tuple.append(nodesList, worker)
    Gossip.createProcesses(numNodes-1, nodesList)
  end

  def checkConvergence(0, b) do
    IO.inspect :os.system_time(:milli_seconds)-b
    IO.inspect "We have converged"
  end
  def checkConvergence(nodesToInform, b) do
    receive do
      #check if a node has been informed of a gossip
      :informed ->
        #IO.inspect "Nodes left: #{nodesToInform}"
        Gossip.checkConvergence(nodesToInform-1, b)
    end
  end

  def segment(nodesList, list2d, tempList, index, len) do
    cond do
      rem(index+1, len) == 0 ->
        cond do 
          index == tuple_size(nodesList) - 1 ->
            # returns the 2-d tuple after reading the last element
            Tuple.append(list2d, Tuple.append(tempList, elem(nodesList, index)))
          true -> 
            segment(nodesList, Tuple.append(list2d, Tuple.append(tempList, elem(nodesList, index))), {}, index + 1, len)
        end
      true ->
        segment(nodesList, list2d, Tuple.append(tempList, elem(nodesList, index)), index + 1, len)
      end
  end
end

defmodule Project2 do
  def main(args) do
    numNodes = args 
              |> parse_args 
              |> Enum.at(0)
              |> Integer.parse(10) 
              |> elem(0) 

    topology = args 
              |> parse_args 
              |> Enum.at(1)
    
    IO.puts "<plotty: draw, #{numNodes}>"

    case topology do
      "full" ->
        numNodes |> Gossip.createProcesses |> Gossip.fullTopology

      "2D" ->
        :math.sqrt(numNodes) 
          |> round
          |> :math.pow(2)
          |> round
          |> Gossip.createProcesses 
          |> Gossip.grid2DTopology

      "line" ->
        numNodes |> Gossip.createProcesses |> Gossip.lineTopology

      "imp2D" ->
        :math.sqrt(numNodes) 
        |> Float.round(0)
        |> :math.pow(2)
        |> Gossip.createProcesses 
        |> Gossip.gridImpTopology
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:string, :integer])
    word
  end
end