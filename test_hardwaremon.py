from hardwaremon.hardwaremon import check_alerts


def test_alerts_returns_list():
    result = check_alerts()
    assert isinstance(result, list)
