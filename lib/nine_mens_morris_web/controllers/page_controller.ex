defmodule NineMensMorrisWeb.PageController do
  use NineMensMorrisWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/lobby")
  end
end
