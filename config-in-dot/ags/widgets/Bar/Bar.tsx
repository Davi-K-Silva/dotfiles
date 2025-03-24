import { App, Widget } from "astal/gtk3";
import { Variable, GLib, bind, exec } from "astal";
import { Astal, Gtk, Gdk } from "astal/gtk3";
import Hyprland from "gi://AstalHyprland";
import Mpris from "gi://AstalMpris";
import Battery from "gi://AstalBattery";
import Wp from "gi://AstalWp";
import Network from "gi://AstalNetwork";
import Tray from "gi://AstalTray";
import Bluetooth from "gi://AstalBluetooth";
import Apps from "gi://AstalApps";
import MprisPlayers from "../Media-player/MediaPlayer";

function SysTray() {
  const tray = Tray.get_default();

  return (
    <box className="SysTray">
      {bind(tray, "items").as((items) =>
        items.map((item) => (
          <menubutton
            tooltipMarkup={bind(item, "tooltipMarkup")}
            usePopover={false}
            actionGroup={bind(item, "actionGroup").as((ag) => ["dbusmenu", ag])}
            menuModel={bind(item, "menuModel")}
          >
            <icon gicon={bind(item, "gicon")} />
          </menubutton>
        )),
      )}
    </box>
  );
}

function Wifi() {
  const network = Network.get_default();
  if (network.get_primary() == Network.Primary.WIFI) {
    const wifi = bind(network, "wifi");
    return (
      <box className="Wifi" visible={wifi.as(Boolean)}>
        {wifi.as(
          (wifi) =>
            wifi && (
              <box className="Wifi">
                <button onClick="kitty nmtui">
                  <icon
                    tooltipText={bind(wifi, "ssid").as(String)}
                    className="Wifi"
                    icon={bind(wifi, "iconName")}
                  />
                </button>
              </box>
            ),
        )}
      </box>
    );
  } else if (network.get_primary() == Network.Primary.WIRED) {
    const wired = bind(network, "wired");
    return (
      <box visible={wired.as(Boolean)} className="Wifi">
        {wired.as(
          (wired) =>
            wired && (
              <box className="Wifi">
                <icon
                  tooltipText={bind(wired, "internet").as(String)}
                  icon={bind(wired, "iconName")}
                />
              </box>
            ),
        )}
      </box>
    );
  }
  return <box></box>;
}

function AudioSlider() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;
  const bluetoth = Bluetooth.get_default();

  // const apps = new Apps.Apps();
  // const pulsemixer = apps.exact_query("Volume Control");

  return (
    <box className="AudioSlider" css="min-width: 140px">
      {bind(bluetoth, "isConnected").as((con) =>
        con ? (
          <icon
            icon={bind(
              bluetoth.get_devices().find((device) => device.connected)!,
              "icon",
            )}
            tooltipText={bind(
              bluetoth.get_devices().find((device) => device.connected)!,
              "name",
            )}
          />
        ) : (
          <label label="" visible={bind(bluetoth, "isConnected")} />
        ),
      )}
      <button onClick="pavucontrol">
        <icon icon={bind(speaker, "volumeIcon")} />
      </button>
      <slider
        hexpand
        onDragged={({ value }) => (speaker.volume = value)}
        value={bind(speaker, "volume")}
      />
    </box>
  );
}

function BatteryLevel() {
  const bat = Battery.get_default();

  return (
    <box className="Battery" visible={bind(bat, "isPresent")}>
      <icon icon={bind(bat, "batteryIconName")} />
      <label
        label={bind(bat, "percentage").as((p) => `${Math.floor(p * 100)} %`)}
      />
    </box>
  );
}

function Media() {
  const newWindow = new Widget.Window({}, MprisPlayers());
  newWindow.visible = false;

  function onClicked(self: Widget.Button) {
    newWindow.visible = !newWindow.visible;
  }

  const mpris = Mpris.get_default();
  return (
    <box className="Media">
      {bind(mpris, "players").as((ps) =>
        ps[0] ? (
          <button onClicked={onClicked} className="Mplayer">
            <box>
              <box
                className="Cover"
                valign={Gtk.Align.CENTER}
                css={bind(ps[0], "coverArt").as(
                  (cover) => `background-image: url('${cover}');`,
                )}
              />
              <label
                visible={bind(ps[0], "canPlay")}
                label={bind(ps[0], "metadata").as(
                  () =>
                    limit(`${ps[0].title}`, 25, "...") +
                    " - " +
                    limit(`${ps[0].artist}`, 15, "..."),
                )}
              />
            </box>
          </button>
        ) : (
          <label label="Nothing Playing" />
        ),
      )}
    </box>
  );
}

function Workspaces() {
  const hypr = Hyprland.get_default();

  return (
    <box className="Workspaces">
      {bind(hypr, "workspaces").as((wss) =>
        wss
          .filter((ws) => !(ws.id >= -99 && ws.id <= -2)) // filter out special workspaces
          .sort((a, b) => a.id - b.id)
          .map((ws) => (
            <button
              className={bind(hypr, "focusedWorkspace").as((fw) =>
                ws === fw ? "focused" : "",
              )}
              onClicked={() => ws.focus()}
            >
              {ws.id}
            </button>
          )),
      )}
    </box>
  );
}

function FocusedClient() {
  const hypr = Hyprland.get_default();
  const focused = bind(hypr, "focusedClient");
  return (
    <box className="Focused" visible={focused.as(Boolean)}>
      {focused.as(
        (client) =>
          client && (
            <label
              label={bind(client, "title").as((title) =>
                limit(title, 20, "..."),
              )}
            />
          ),
      )}
    </box>
  );
}

function Time({ format = "%H:%M - %A %e." }) {
  const time = Variable<string>("").poll(
    1000,
    () => GLib.DateTime.new_now_local().format(format)!,
  );

  return (
    <label className="Time" onDestroy={() => time.drop()} label={time()} />
  );
}

export default function Bar(monitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      className="Bar"
      gdkmonitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
    >
      <centerbox>
        <box hexpand halign={Gtk.Align.START}>
          <Workspaces />
          <FocusedClient />
        </box>
        <box>
          <Media />
        </box>
        <box hexpand halign={Gtk.Align.END}>
          <SysTray />
          <Wifi />
          <AudioSlider />
          <BatteryLevel />
          <Time />
        </box>
      </centerbox>
    </window>
  );
}

// Aux functions ----------------------------------------- //
/**
 * Returns the first `limit` characters from the given `string` and add a 'tail' string.
 *
 * @param {String} string
 * @param {Number} limit
 * @param {String} tail
 *
 * @returns {String}
 */
function limit(string = "", limit = 0, tail = "") {
  if (string.length <= limit) {
    tail = "";
  }
  return string.substring(0, limit).trimEnd() + tail;
}
