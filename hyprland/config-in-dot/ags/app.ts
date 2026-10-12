import { App } from "astal/gtk3";
import style from "./style.scss";
import Bar from "./widgets/Bar/Bar";
import NotificationPopups from "./widgets/Notification/NotificationPopups";

App.start({
  css: style,
  instanceName: "bar",
  requestHandler(request, res) {
    print(request);
    res("ok");
  },
  main: () => {
    App.get_monitors().map(Bar);
    App.get_monitors().map(NotificationPopups);
  },
});
