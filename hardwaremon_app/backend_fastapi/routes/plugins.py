from __future__ import annotations

import base64

from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException

from plugins.broker import KNOWN_CAPABILITIES, PLUGIN_API_VERSION, PluginBroker, PluginError


router = APIRouter(prefix="/plugins", tags=["plugins"])
plugin_broker = PluginBroker()


class GrantRequest(BaseModel):
    capabilities: list[str] = Field(default_factory=list, max_length=32)


class EnableRequest(BaseModel):
    enabled: bool


class InstallRequest(BaseModel):
    content_base64: str = Field(min_length=1, max_length=36_000_000)


def _translate(action):
    try:
        return action()
    except PluginError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("")
async def list_plugins():
    return {
        "api_version": PLUGIN_API_VERSION,
        "known_capabilities": sorted(KNOWN_CAPABILITIES),
        "plugins": plugin_broker.list_plugins(),
    }


@router.post("/install")
async def install_plugin(request: InstallRequest):
    try:
        payload = base64.b64decode(request.content_base64, validate=True)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Plugin package is not valid base64") from exc
    return _translate(lambda: plugin_broker.install_archive(payload))


@router.get("/{plugin_id}")
async def plugin_details(plugin_id: str):
    return _translate(lambda: plugin_broker.plugin_details(plugin_id))


@router.put("/{plugin_id}/grants")
async def set_plugin_grants(plugin_id: str, request: GrantRequest):
    return _translate(lambda: plugin_broker.set_grants(plugin_id, request.capabilities))


@router.put("/{plugin_id}/enabled")
async def set_plugin_enabled(plugin_id: str, request: EnableRequest):
    return _translate(lambda: plugin_broker.set_enabled(plugin_id, request.enabled))


@router.post("/{plugin_id}/restart")
async def restart_plugin(plugin_id: str):
    def restart():
        plugin_broker.stop_plugin(plugin_id)
        plugin_broker.launch(plugin_id)
        return plugin_broker.plugin_details(plugin_id)
    return _translate(restart)


@router.delete("/{plugin_id}")
async def remove_plugin(plugin_id: str):
    _translate(lambda: plugin_broker.remove_plugin(plugin_id))
    return {"removed": True, "id": plugin_id}
