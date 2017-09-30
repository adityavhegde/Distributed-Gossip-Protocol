defmodule DistributedGossipProtocolTest do
  use ExUnit.Case
  doctest DistributedGossipProtocol

  test "greets the world" do
    assert DistributedGossipProtocol.hello() == :world
  end
end
