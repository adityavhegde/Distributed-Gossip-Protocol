defmodule GossipSpread do
  @interval 1
  def rumor(neighbors_list, counter, master) do
    cond do
      #stop the process when counter reaches 10
      counter >= 10 ->
        #IO.puts "<plotty: inactive, #{self()}>"
        exit(:shutdown)
    true ->
      receive do
        :gossip ->
          case counter do
            #got the rumor for the first time
            0 ->
              send master, :informed
              #IO.puts "<plotty: infected, #{self()}>"
          end
          GossipSpread.rumor(neighbors_list, counter+1, master) 
        updated_neighbors_list ->
          GossipSpread.rumor(updated_neighbors_list, counter, master)
      after 
        @interval ->
          cond do
            #check if this node even knows the gossip
            counter > 0 and Enum.count(neighbors_list)!=0->
              selectedNeighbor = neighbors_list |> Enum.random
              cond do
                Process.alive?(selectedNeighbor) ->
                send selectedNeighbor, :gossip
              true ->
                List.delete(neighbors_list, selectedNeighbor)
                GossipSpread.rumor(neighbors_list, counter, master)
              end
            true ->
              GossipSpread.rumor(neighbors_list, counter, master)
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
      if (i-1) >= 0 do
        neighbors_i = neighbors_i ++ [nodesList |> elem(i-1)]
      end
      if (i+1) <numNodes do
        neighbors_i = neighbors_i ++ [nodesList |> elem(i+1)]
      end
      currentNode = nodesList |> elem(i)
      send currentNode, neighbors_i
    end)
    b = :os.system_time(:milli_seconds)
    send nodesList |> elem(0), :gossip
    Gossip.checkConvergence(numNodes, b)
  end


  def grid2DTopology(nodesList) do

    len = :math.sqrt(tuple_size(nodesList)) |> round

    list2d = Gossip.segment(nodesList, {}, {}, 0, len)
    
    Enum.each(0..len-1, fn(i) -> 
      Enum.each(0..len-1, fn(j) ->
        neighbors = []
        cond do
          i-1 >= 0 ->
            neighbors = neighbors ++ [list2d |> elem(i-1) |> elem(j)]
          true ->true
        end 

        cond do
          i+1 < len ->
            neighbors = neighbors ++ [list2d |> elem(i+1) |> elem(j)]
          true -> true
        end 

        cond do
          j-1 >= 0 ->
            neighbors = neighbors ++ [list2d |> elem(i) |> elem(j-1)]
          true -> true
        end

        cond do
          j + 1 < len ->
            neighbors = neighbors ++ [list2d |> elem(i) |> elem(j+1)]
          true -> true
        end

        #send
          send list2d |> elem(i) |> elem(j), neighbors   

      end)
    end)

    send list2d |> elem(0) |> elem(0), :gossip 
    
  end

  def gridImpTopology(nodesList) do
  
  end

  def fullTopology(nodesList) do
    Enum.each(0..tuple_size(nodesList), fn(index) -> 
      send nodesList |> elem(index), Tuple.to_list(nodesList) -- [elem(nodesList, index)]
    end) 
    send nodesList |> elem(0), :gossip
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
    worker = Node.self() |> Node.spawn(GossipSpread, :rumor, [[], 0, self()])
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
    
    #IO.puts "<plotty: draw, #{numNodes}>"

    case topology do
      "full" ->
        numNodes |> Gossip.createProcesses |> Gossip.fullTopology

      "2D" ->
        :math.sqrt(numNodes) 
          |> Float.round(0)
          |> :math.pow(2)
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
