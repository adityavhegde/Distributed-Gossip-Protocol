defmodule Gossip do
  
end

defmodule Project2 do
  def main(args) do
    topology = args 
              |> parse_args 
              |> Enum.at(0)
    case topology do
      full - >
        #call full topology
      2D ->
        #call 2D grid
      line ->
        #call line grid
      imp2D ->
        #call imperfect 2D grid
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args 
    |> OptionParser.parse(strict: [:string])
    word
  end
end
