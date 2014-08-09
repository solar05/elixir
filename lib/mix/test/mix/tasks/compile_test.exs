Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Tasks.CompileTest do
  use MixTest.Case

  defmodule CustomCompilers do
    def project do
      [compilers: [:elixir, :app, :custom]]
    end
  end

  setup do
    Mix.Project.push MixTest.Case.Sample
    :ok
  end

  test "mix compile --list with mixfile" do
    Mix.Tasks.Compile.run ["--list"]
    assert_received {:mix_shell, :info, ["\nEnabled compilers: yecc, leex, erlang, elixir, app"]}
    assert_received {:mix_shell, :info, ["mix compile.elixir    # " <> _]}
  end

  test "mix compile --list with custom mixfile" do
    Mix.Project.push CustomCompilers
    Mix.Tasks.Compile.run ["--list"]
    assert_received {:mix_shell, :info, ["\nEnabled compilers: elixir, app, custom"]}
  end

  test "compile a project with mixfile" do
    in_fixture "no_mixfile", fn ->
      Mix.Tasks.Compile.run []
      assert File.regular?("_build/dev/lib/sample/ebin/Elixir.A.beam")
      assert File.regular?("_build/dev/lib/sample/ebin/sample.app")
      assert_received {:mix_shell, :info, ["Compiled lib/a.ex"]}
      assert_received {:mix_shell, :info, ["Generated sample.app"]}
    end
  end

  test "compile a project with multiple compilers and a syntax error in an erlang file" do
    in_fixture "no_mixfile", fn ->
      import ExUnit.CaptureIO

      File.mkdir! "src"
      File.write! "src/a.erl", """
      -module(b).
      def b(), do: b
      """
      assert File.regular?("src/a.erl")

      assert_raise CompileError, fn ->
        capture_io fn -> Mix.Tasks.Compile.run ["--force"] end
      end

      refute File.regular?("ebin/Elixir.A.beam")
      refute File.regular?("ebin/Elixir.B.beam")
      refute File.regular?("ebin/Elixir.C.beam")
    end
  end

  test "recompiles project if elixir version changed" do
    in_fixture "no_mixfile", fn ->
      Mix.Tasks.Compile.run []
      purge [A, B, C]

      assert_received {:mix_shell, :info, ["Compiled lib/a.ex"]}
      assert System.version == Mix.Dep.Lock.elixir_vsn

      Mix.Task.clear
      File.write!("_build/dev/lib/sample/.compile.lock", "the_past")
      File.touch!("_build/dev/lib/sample/.compile.lock", {{2010, 1, 1}, {0, 0, 0}})

      Mix.Tasks.Compile.run []
      assert System.version == Mix.Dep.Lock.elixir_vsn
      assert File.stat!("_build/dev/lib/sample/.compile.lock").mtime > {{2010, 1, 1}, {0, 0, 0}}
    end
  end
end
