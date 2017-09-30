defmodule Gossip do
  
end

defmodule Project2 do
  def main(args) do
    topology = args 
              |> parse_args 
              |> Enum.at(0)
    cond do topology
  end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:string])
    word
  end
end
