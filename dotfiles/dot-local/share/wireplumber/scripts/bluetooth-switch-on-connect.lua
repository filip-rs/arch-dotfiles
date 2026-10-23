-- Make a Bluetooth output the default sink the moment it connects, like
-- PulseAudio's module-switch-on-connect. Loaded by
-- wireplumber.conf.d/52-bluetooth-switch-on-connect.conf.
--
-- On its own WirePlumber only switches to a device that is still the
-- "configured" default, i.e. the last one picked by hand. Picking the speakers
-- once, or Sunshine handing the default back to them after a stream, would
-- otherwise stop the AirPods from taking over when they connect. On disconnect
-- WirePlumber falls back through its stored history as usual.

log = Log.open_topic ("s-custom")

SimpleEventHook {
  name = "custom/bluetooth-switch-on-connect",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "media.class", "=", "Audio/Sink" },
      Constraint { "device.api", "=", "bluez5", type = "pw" },
    },
  },
  execute = function (event)
    local name = event:get_subject ().properties ["node.name"]
    local om = event:get_source ():call ("get-object-manager", "metadata")
    local metadata = om:lookup { Constraint { "metadata.name", "=", "default" } }
    if name == nil or metadata == nil then
      return
    end

    log:info ("bluetooth output " .. name .. " connected, making it the default")
    metadata:set (0, "default.configured.audio.sink", "Spa:String:JSON",
        Json.Object { ["name"] = name }:to_string ())
  end
}:register ()
