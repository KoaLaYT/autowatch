const std = @import("std");
const win32 = struct {
    usingnamespace @import("zigwin32").zig;
    usingnamespace @import("zigwin32").foundation;
    usingnamespace @import("zigwin32").ui.windows_and_messaging;
    usingnamespace @import("zigwin32").ui.input.keyboard_and_mouse;
};

const Window = struct {
    hwnd: win32.HWND,
    x: usize,
    y: usize,
    width: usize,
    height: usize,
    desktop_width: usize,
    desktop_height: usize,

    const Self = @This();

    fn init(hwnd: win32.HWND) Self {
        var info = std.mem.zeroes(win32.WINDOWINFO);
        info.cbSize = @sizeOf(win32.WINDOWINFO);
        _ = win32.GetWindowInfo(hwnd, &info);
        const x = info.rcWindow.left;
        const y = info.rcWindow.top;
        const width = info.rcWindow.right - info.rcWindow.left;
        const height = info.rcWindow.bottom - info.rcWindow.top;

        const desktop = win32.GetDesktopWindow();
        _ = win32.GetWindowInfo(desktop, &info);
        const desktop_width = info.rcWindow.right - info.rcWindow.left;
        const desktop_height = info.rcWindow.bottom - info.rcWindow.top;

        return .{
            .hwnd = hwnd,
            .x = @intCast(x),
            .y = @intCast(y),
            .width = @intCast(width),
            .height = @intCast(height),
            .desktop_width = @intCast(desktop_width),
            .desktop_height = @intCast(desktop_height),
        };
    }

    fn autowatch(self: *const Self) void {
        std.debug.print("window size {d}x{d}, at ({d},{d})\n", .{
            self.width, self.height,
            self.x,     self.y,
        });
        std.debug.print("desktop size {d}x{d}\n", .{
            self.desktop_width, self.desktop_height,
        });

        self.activate_and_click();

        std.debug.print("window activated, start auto watching\n", .{});

        for (0..30) |i| {
            std.debug.print("watch #{d}\n", .{i + 1});

            // 点聊天记录里的小程序卡片
            if (i == 29) {
                self.open_miniapp_at(500);
            } else {
                self.open_miniapp_at(250);
            }
            // 点小程序里的按钮
            self.click_miniapp();
            // 重新激活聊天记录窗口
            self.activate_and_click();

            // 移动下一个卡片
            // 一般移动11下，每5次校准一下
            var scroll_times: usize = 11;
            if (i > 0 and i % 5 == 0) {
                scroll_times = 10;
            }
            for (0..scroll_times) |_| {
                self.mouse_move_abs(self.x + self.width / 2, self.y + self.height / 2);
                self.wheel_scroll();
            }
        }
    }

    fn click_miniapp(self: *const Self) void {
        self.mouse_move_abs(self.desktop_width / 2, self.desktop_height / 2 - 390 + 575);
        self.mouse_click();
    }

    fn open_miniapp_at(self: *const Self, y_offset: usize) void {
        self.mouse_move_abs(self.x + 200, self.y + y_offset);
        self.mouse_click();
        slow_down(3000);
    }

    fn activate_and_click(self: *const Self) void {
        _ = win32.SetForegroundWindow(self.hwnd);
        slow_down(500);

        self.mouse_move_abs(self.x + self.width / 2, self.y + 10);
        self.mouse_click();
    }

    fn slow_down(ms: u64) void {
        std.time.sleep(ms * std.time.ns_per_ms);
    }

    fn wheel_scroll(self: *const Self) void {
        var input = std.mem.zeroes(win32.INPUT);
        input.type = win32.INPUT_MOUSE;
        input.Anonymous.mi.mouseData = -120; // one unit
        input.Anonymous.mi.dwFlags = win32.MOUSEEVENTF_WHEEL;
        const inputs: *[1]win32.INPUT = &input;
        _ = win32.SendInput(1, inputs, @sizeOf(win32.INPUT));

        slow_down(100);
        _ = self;
    }

    fn mouse_click(self: *const Self) void {
        _ = self;
        var inputs: [2]win32.INPUT = .{
            std.mem.zeroes(win32.INPUT),
            std.mem.zeroes(win32.INPUT),
        };

        inputs[0].type = win32.INPUT_MOUSE;
        inputs[0].Anonymous.mi.dx = 0;
        inputs[0].Anonymous.mi.dy = 0;
        inputs[0].Anonymous.mi.dwFlags = win32.MOUSEEVENTF_LEFTDOWN;

        inputs[1].type = win32.INPUT_MOUSE;
        inputs[1].Anonymous.mi.dx = 0;
        inputs[1].Anonymous.mi.dy = 0;
        inputs[1].Anonymous.mi.dwFlags = win32.MOUSEEVENTF_LEFTUP;

        _ = win32.SendInput(inputs.len, &inputs, @sizeOf(win32.INPUT));

        slow_down(500);
    }

    fn mouse_move_abs(self: *const Self, x: usize, y: usize) void {
        var input = std.mem.zeroes(win32.INPUT);
        input.type = win32.INPUT_MOUSE;
        input.Anonymous.mi.dx = @intCast(65536 * x / self.desktop_width);
        input.Anonymous.mi.dy = @intCast(65536 * y / self.desktop_height);
        input.Anonymous.mi.dwFlags = win32.MOUSE_EVENT_FLAGS{
            .ABSOLUTE = 1,
            .MOVE = 1,
            .VIRTUALDESK = 1,
        };
        const inputs: *[1]win32.INPUT = &input;
        _ = win32.SendInput(1, inputs, @sizeOf(win32.INPUT));

        slow_down(500);
    }
};

fn findTargetWindow() ?win32.HWND {
    var hwnd: ?win32.HWND = null;
    _ = win32.EnumWindows(enumWindowCb, @intCast(@intFromPtr(&hwnd)));
    return hwnd;
}

fn enumWindowCb(hwnd: win32.HWND, lparam: win32.LPARAM) callconv(std.os.windows.WINAPI) win32.BOOL {
    var title: [1024:0]u8 = undefined;
    const length = win32.GetWindowTextA(hwnd, &title, 1024);
    const len: usize = @intCast(length);

    if (win32.IsWindowVisible(hwnd) == win32.FALSE) {
        return win32.TRUE;
    }

    const i = std.mem.indexOf(u8, title[0..len], "茉茉斯羽");
    if (i) |_| {
        const result: *win32.HWND = @ptrFromInt(@as(usize, @intCast(lparam)));
        result.* = hwnd;
        return win32.FALSE;
    }

    if (std.mem.eql(u8, title[0..len], "微信")) {
        var info = std.mem.zeroes(win32.WINDOWINFO);
        info.cbSize = @sizeOf(win32.WINDOWINFO);
        _ = win32.GetWindowInfo(hwnd, &info);
        const width = info.rcClient.right - info.rcClient.left;
        const height = info.rcClient.bottom - info.rcClient.top;
        if (width == 640 and height == 800) {
            const result: *win32.HWND = @ptrFromInt(@as(usize, @intCast(lparam)));
            result.* = hwnd;
            return win32.FALSE;
        }
    }

    return win32.TRUE;
}

pub fn main() !void {
    if (findTargetWindow()) |hwnd| {
        std.debug.print("find target window {any}\n", .{hwnd});
        const window = Window.init(hwnd);
        window.autowatch();
    } else {
        std.debug.print("cannot find target window\n", .{});
    }
}
