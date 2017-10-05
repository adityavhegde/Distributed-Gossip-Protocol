defmodule GossipSpread do
  @interval 1
  def rumor(neighbors_list, counter, master, procId) do
    #stop the process when counter reaches 10
    if counter >= 10 do
      IO.puts "<plotty: inactive, #{procId}>"
      receive do
        :terminate ->
          rumor(neighbors_list, counter, master, procId)
      end
    #otherwise wait for gossip or neighbors list
    else
      receive do
        :gossip ->
          #IO.inspect procId
          if counter == 0 do
            IO.puts "<plotty: infected, #{procId}>"
            send master, :informed
          end
          #check if this node even knows the gossip
          selectedNeighbor = neighbors_list |> Enum.random
          send selectedNeighbor, :gossip
          GossipSpread.rumor(neighbors_list, counter+1, master, procId)
        neighbors_list ->
          GossipSpread.rumor(neighbors_list, counter, master, procId)
      after 
        @interval ->
          #check if this node even knows the gossip, select a random neighbor if true, and forward the gossip
          if counter > 0 do
            selectedNeighbor = neighbors_list |> Enum.random
            send selectedNeighbor, :gossip
          end
          GossipSpread.rumor(neighbors_list, counter, master, procId)
      end
    end
  end

  def pushsum(neighbors_list, s, w, past, procId, master) do
    receive do
      #if received a (s,w) pair, add it to your current, half it and send half forward
      {rec_s, rec_w} -> 
        final_s = (s+rec_s)/2
        final_w = (w+rec_w)/2
        send neighbors_list |> Enum.random, {final_s, final_w}
        final_sw = final_s/final_w
        
        cond do  
          #check if this is the first time you are receiving (s,w) pair
          Enum.count(past) == 0 ->
            IO.puts "<plotty: infected, #{procId}>"
            pushsum(neighbors_list, final_s, final_w, past ++ [final_sw], procId, master)
          #check if you have not yet gone through 3 rounds
          Enum.count(past) < 3 ->
            pushsum(neighbors_list, final_s, final_w, past ++ [final_sw], procId, master)
          #if more than 3 rounds done, check if no "significant" change has happened for last 3 consecutive rounds
          true -> 
            a = abs(final_sw - s/w)
            b = abs(Enum.at(past, 2) - Enum.at(past, 1))
            c = abs(Enum.at(past, 1) - Enum.at(past, 0))
            #if no "significant change has happened, pause this process"
            if a < :math.pow(10, -10) and b < :math.pow(10, -10) and c < :math.pow(10, -10) do
              IO.puts "<plotty: inactive, #{procId}>"
              IO.inspect final_sw
              send master, :converged
              receive do
                :terminate -> 
                  pushsum(neighbors_list, s, w, past, procId, master)
              end
            end
            pushsum(neighbors_list, final_s, final_w, tl(past) ++ [final_sw], procId, master)
        end
      neighbors_list ->
        pushsum(neighbors_list, s, w, past, procId, master) 
    after 
      @interval ->
        if Enum.count(past) > 0 do
          final_s = s/2
          final_w = w/2
          send neighbors_list |> Enum.random, {final_s, final_w}
          final_sw = final_s/final_w  
          cond do  
            #check if you have not yet gone through 3 rounds
            Enum.count(past) < 3 ->
              pushsum(neighbors_list, final_s, final_w, past ++ [final_sw], procId, master)
              #if more than 3 rounds done, check if no "significant" change has happened for last 3 consecutive rounds
            true -> 
              a = abs(final_sw - s/w)
              b = abs(Enum.at(past, 2) - Enum.at(past, 1))
              c = abs(Enum.at(past, 1) - Enum.at(past, 0))
              #if no "significant change has happened, pause this process"
              if a < :math.pow(10, -10) and b < :math.pow(10, -10) and c < :math.pow(10, -10) do
                IO.puts "<plotty: inactive, #{procId}>"
                IO.inspect final_sw
                send master, :converged
                receive do
                  :terminate -> 
                    pushsum(neighbors_list, s, w, past, procId, master)
                end
              end
              pushsum(neighbors_list, final_s, final_w, tl(past) ++ [final_sw], procId, master)
          end 
        end
        pushsum(neighbors_list, s, w, past, procId, master)         
    end
  end
end

defmodule Gossip do
  def lineTopology(nodesList) do
    numNodes = tuple_size(nodesList)
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
        (i+1) < numNodes ->
          neighbors_i ++ [nodesList |> elem(i+1)]
        true ->
          neighbors_i ++ [nodesList |> elem(0)]
      end
      currentNode = nodesList |> elem(i)
      send currentNode, neighbors_i
    end)
  end

  def grid2DTopology(nodesList, imperfect) do
    #numNodes = tuple_size(nodesList)
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
        cond do #TODO: question -> can the randomly selected node be an existing neighbor
          imperfect == :imperf ->
            neighbors_ij = neighbors_ij ++ [Tuple.to_list(nodesList) -- [list2d |> elem(i) |> elem(j)|neighbors_ij] |> Enum.random]
            send list2d |> elem(i) |> elem(j), neighbors_ij
          true -> 
            send list2d |> elem(i) |> elem(j), neighbors_ij
          end
      end)
    end)
  end

  def fullTopology(nodesList) do
    numNodes = tuple_size(nodesList)
    Enum.each(0..numNodes-1, fn(i) -> 
      #send this nodes all the nodes other than itself, as neighbors
      send nodesList |> elem(i), Tuple.to_list(nodesList) -- [elem(nodesList, i)]
    end) 
  end

  # takes args of num of processes to be created and returns a list of process ids
  def createProcesses(numNodes, algorithm) do
    nodesList = {}
    Gossip.createProcesses(numNodes, nodesList, algorithm)
  end
  def createProcesses(0, nodesList, _) do
    nodesList
  end
  #if gossip algorithm
  def createProcesses(numNodes, nodesList, :gossip) do
    worker = Node.self() |> Node.spawn(GossipSpread, :rumor, [[], 0, self(), numNodes])
    nodesList = Tuple.append(nodesList, worker)
    Gossip.createProcesses(numNodes-1, nodesList, :gossip)
  end
  #if push-sum algorithm
  def createProcesses(numNodes, nodesList, :pushsum) do
    w = 1
    s = numNodes
    worker = Node.self() |> Node.spawn(GossipSpread, :pushsum, [[], s, w, [], numNodes, self()])
    nodesList = Tuple.append(nodesList, worker)
    Gossip.createProcesses(numNodes-1, nodesList, :pushsum)
  end

  def checkConvergence(0, b) do
    IO.inspect "Time to converge: #{:os.system_time(:milli_seconds)-b} milliseconds"
    receive do 
      :ok ->
        :ok
    end
  end
  def checkConvergence(nodesToInform, b) do
    receive do
      #check if a node has been informed of a gossip
      :informed ->
        Gossip.checkConvergence(nodesToInform-1, b)
      #check if a node has gone to stable state in push-sum
      :converged ->
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
    
    algorithm = args
              |> parse_args
              |> Enum.at(2)
    
    algorithm = 
      if algorithm == "gossip" do
        :gossip
      else 
        :pushsum
      end
    
    IO.puts "<plotty: draw, #{numNodes}>"

    case topology do
      "full" ->
        nodesList = numNodes |> Gossip.createProcesses(algorithm) 
        nodesList |> Gossip.fullTopology

      "line" ->
        nodesList = numNodes |> Gossip.createProcesses(algorithm) 
        Gossip.lineTopology(nodesList)

      "2D" ->
        nodesList = :math.sqrt(numNodes) 
                    |> round
                    |> :math.pow(2)
                    |> round
                    |> Gossip.createProcesses(algorithm) 
        nodesList |> Gossip.grid2DTopology(:perf)

      "imp2D" ->
        nodesList = :math.sqrt(numNodes) 
                    |> Float.round(0)
                    |> :math.pow(2)
                    |> round
                    |> Gossip.createProcesses(algorithm) 
        nodesList |> Gossip.grid2DTopology(:imperf) 
    end  

      b = :os.system_time(:milli_seconds)
      cond do 
        algorithm == :gossip ->
          send nodesList |> elem(0), :gossip
          Gossip.checkConvergence(numNodes, b)
        true -> 
         send nodesList |> Tuple.to_list |> Enum.random, {0, 0}
         Gossip.checkConvergence(numNodes, b)
      end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:integer, :string, :string])
    word
  end
end