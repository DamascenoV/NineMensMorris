defmodule NineMensMorris do
  @moduledoc """
  NineMensMorris keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Returns the application version.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:nine_mens_morris, :vsn) || "0.1.0"
  end

  @doc """
  Returns application configuration for the given key.
  """
  @spec config(atom()) :: any()
  def config(key) do
    Application.get_env(:nine_mens_morris, key)
  end
end
