defmodule AppKit.RemoteFacade.ProductSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.Transport
  alias AppKit.RemoteFacade.ProductSurface

  test "declares owner-defined product surface group" do
    assert ProductSurface.owner_group() == {ProductSurface, :product_surface}
  end

  test "submits valid product envelope through configured Mezzanine transport" do
    assert {:ok, %{"accepted_ref" => "fixture://accepted"}} =
             ProductSurface.submit_work(valid_envelope(),
               transport: Transport.Fixture,
               transport_opts: [submit_work: {:ok, %{"accepted_ref" => "fixture://accepted"}}]
             )
  end

  test "rejects missing tenant before transport" do
    assert {:error, %{"code" => "invalid_envelope", "missing_field" => "tenant_ref"}} =
             valid_envelope()
             |> Map.delete("tenant_ref")
             |> ProductSurface.submit_work(transport: Transport.Fixture)
  end

  test "rejects raw payload mode" do
    assert {:error, %{"code" => "payload_not_allowed"}} =
             valid_envelope()
             |> Map.put("payload_mode", "raw_payload")
             |> ProductSurface.submit_work(transport: Transport.Fixture)
  end

  test "readback delegates through configured transport" do
    assert {:ok, %{"status" => "accepted"}} =
             ProductSurface.readback("work://accepted",
               transport: Transport.Fixture,
               transport_opts: [readback: {:ok, %{"status" => "accepted"}}]
             )
  end

  defp valid_envelope do
    %{
      "schema_ref" => "app_kit.product_work.v1",
      "tenant_ref" => "tenant://one",
      "correlation_ref" => "corr://one",
      "idempotency_key" => "idem://one",
      "trace_ref" => "trace://one",
      "payload_mode" => "refs_only",
      "redaction_class" => "tenant_sensitive"
    }
  end
end
