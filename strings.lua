local descEN = [[This is my last gift for you.
As a modder I seldom get time to really play with the game, this mod, together with the free tracks option in the recent update is the feedback from myself after playing a while the game, after I think to stop develope mods for the game.
Use this mod like the similar one in the Ultimate Station mod. Place two markers of the same grouo then use the "Preview" button to visualize the plan, and "Build" button to build.
In preview mode you can adjust wall and other options to see the difference, which may be insteresting.
You can use free tracks option to build all modifiable tracks.

This planner will be able to generate cuvers between two directed points, the result depends where and how you place the markers. The track between the two markers can be a straight, a single curvature or an S curvature tracks.
Possiblely to has transitional straight tracks between two curvartures and markers, if you define a radius in any name of the marker beginning with #.
For example:
Name a marker as #120 with limit all curvatures to a max radius of 120m.

This planner is useful when you can to connect two tracks together, with an elegant circular curve and straight line (instead of bézier-like curves in the game), or want to put some constraints on the tracks that you build.
However, the slope of generated tracks will always be a constant slope since there no way to read the slope of existing tracks, so you need to carefully deal with the slope transition with tracks you build with it.

* Livetext is mandatory to run this mod

Changelog
1.1 Fixed erroneous curves when two markers form a sharpe angle or an U-turn.
]]

local descZH = [[这是我给你的最后一份礼物。
作为一个Modder，我很少有时间真正玩游戏，这个mod以及最近更新中的自由轨道选项是我在决定停止制作Mod之后玩了一段时间游戏之后的对自己的反馈。
这个MOD的使用方法和终极车站中的类似工具差不多——放置两个同一组的标记，然后使用“预览”按钮预览，并使用“建造”按钮进行建造。
您可以使用自由轨道选项来构建所有可修改的轨道。

此规划工具可以在有标记生成各种曲线，结果取决于放置标记的位置和方式。两个标记之间的轨迹可以是直线，简单圆曲线或者反向圆曲线。
如果您以＃开头的任何标记名称定义半径，则可能在两个曲线之间见到一些直线。
例如：
将其中一个标记命名为＃120，将所有曲线最大半径限制120米。

当您想将两条轨道连接在一起时，此计划工具会比较有用，它可以生成优雅的圆曲线和直线（不像游戏类似贝塞尔曲线的非定圆曲线），或者如果您想对要构建的轨道施加一些约束。
但是，由于无法读取现有轨道的坡度，因此生成的轨道的坡度将始终是恒定的，您需要自己处理连接处的坡度过渡。

* 本MOD需要Livetext支持
]]

function data()
    return {
        en = {
            ["name"] = "Track Design Patterns Planner",
            ["desc"] = descEN,
        },
        zh_CN = {
            ["name"] = "模式轨道（参数化轨道）规划工具",
            ["desc"] = descZH,
            ["group"] = "分组",
            ["Number of tracks"] = "轨道数"
        }
    }
end
