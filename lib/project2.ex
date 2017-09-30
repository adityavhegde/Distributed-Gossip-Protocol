defmodule Gossip do
  
  @doc """"

  """
  def grid2DTopology(nodesList) do
    
  end

  def gridImpTopology(nodesList) do

  end

  def fullTopology(nodesList) do
  
  end

  # takes args of num of processes to be created and returns a list of process ids
  def createProcesses(numProcesses) do

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
      full - >
        createProcesses |> fullTopology
        
      2D ->
        :math.sqrt(numNodes) 
          |> Float.round(0)
          |> :math.pow(2)
          |> createProcesses 
          |> grid2DTopology
      
      line ->
        createProcesses |> lineTopology
        
      imp2D ->
        :math.sqrt(numNodes) 
        |> Float.round(0)
        |> :math.pow(2)
        |> createProcesses 
        |> gridImpTopology
    
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:string])
    word
  end
end
