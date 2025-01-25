defmodule NineMensMorrisWeb.ErrorJSONTest do
  use NineMensMorrisWeb.ConnCase, async: true

  test "renders 404" do
    assert NineMensMorrisWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert NineMensMorrisWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
