# ActionScript3-Script-Engine

一个轻量级、嵌入型的 ActionScript 3 脚本执行引擎。它可以解析并执行脚本代码，支持完整类路径反射、控制流、函数调用以及异步执行。

可用于Flash游戏的外挂制作。

---

## 特性

- **脚本语法**
  - `var`
    ```as3
    var a = 1;
    var b = 3.14;
    var c = "Hello";
    var d = [1,2,3];
    var e = true;
    var f;    // undefined;
    var g = null;
    ```
  - `if / else / while / break / continue`
    ```as3
    if(a >= 5 && !b) {
      ...
    }
    ```
  - `function / return`
    ```as3
    function add(a, b) {
      return a + b;
    }
    ```
-**访问类** 
  - 可只有public成员或方法可以访问。
  - 可直接使用全路径包名访问类，例如：
    ```as3
    control.data.DataBackpackControl.getInstance().useProp(...)
    ```
  - 也可使用import pkg.CLass访问类，例如：
    ```as3
    import control.data.DataBackpackControl as DBC;
    DBC.getInstance().useProp(...)
    ```
  - 还可以使用new来调用类的构造函数，例如：
    ```as3
    var p = new flash.geom.Point(100, 200);
    log("point:", p.x, p.y);

    import flash.geom.Rectangle;
    var rect = new Rectangle(10, 20, 100, 50);
    log(rect.width, rect.height);
    ```

- **内置函数**
  - `log(...)` —— 输出日志
  - `delay(ms)` —— 异步延迟
  - `click(x, y, verbose=false)` —— 模拟鼠标点击
  - `getColor(x, y)` —— 获取屏幕像素颜色


---

## 示例

```as3
import control.room.RoomControl;
import data.GameData;

function leaveInstance() {
    RoomControl.getInstance().requestLeave();
}

var i = 0;
while (i <= 20) {
    log("您的血量为：" + GameData.me.HP);
    if(GameData.me.HP < 100) {
      break;
    }
    if(GameData.me.MP >= 50 && GameData.me.HP >= 300) {
      continue;
    }
    delay(1000);
}

RoomControl.getInstance().mRoomState = 3;
leaveInstance();
