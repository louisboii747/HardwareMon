from fastapi.testclient import TestClient

from main import app


def test_inventory_contract_has_extensible_categories():
    response = TestClient(app).get("/inventory")
    assert response.status_code == 200
    payload = response.json()
    assert payload["cpu"]["logical_cores"] >= 1
    assert isinstance(payload["storage"], list)
    assert isinstance(payload["network_adapters"], list)
    assert payload["operating_system"]["name"]
    assert "usb_devices" in payload
    assert "provider_status" in payload
