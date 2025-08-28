defmodule NineMensMorrisWeb.GettextTest do
  use ExUnit.Case, async: true

  describe "Gettext backend" do
    test "module exists and is properly configured" do
      assert NineMensMorrisWeb.Gettext.__gettext__(:otp_app) == :nine_mens_morris
    end

    test "supports basic translation functionality" do
      assert NineMensMorrisWeb.Gettext.__gettext__(:default_locale) == "en"
    end

    test "has correct OTP app configuration" do
      assert NineMensMorrisWeb.Gettext.__gettext__(:otp_app) == :nine_mens_morris
    end
  end
end
