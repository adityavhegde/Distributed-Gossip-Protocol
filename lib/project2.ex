defmodule Gossip do
  
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
  def createProcesses(numProcesses) do

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

    topology = args 
              |> parse_args 
              |> Enum.at(1)

    case topology do
      "full" ->
        Gossip.createProcesses(numNodes) |> Gossip.fullTopology

      "2D" ->
        :math.sqrt(numNodes) 
          |> Float.round(0)
          |> :math.pow(2)
          |> Gossip.createProcesses(numNodes)
          |> Gossip.grid2DTopology
      
      "line" ->
        Gossip.createProcesses(numNodes) |> Gossip.lineTopology
        
      "imp2D" ->
        :math.sqrt(numNodes) 
        |> Float.round(0)
        |> :math.pow(2)
        |> Gossip.createProcesses(numNodes) 
        |> Gossip.gridImpTopology
    
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:string])
    word
  end
end
