from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Final

from batocera_common.configparser import CaseSensitiveConfigParser

from ... import Command
from ...batoceraPaths import BIOS, HOME, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from collections.abc import Mapping

    from ...config import SystemConfig
    from ...controller import Controllers
    from ...Emulator import Emulator
    from ...gun import Guns
    from ...input import Input
    from ...types import DeviceInfoMapping, HotkeysContext, Resolution

_AETHERSX2_BIN: Final = Path("/usr/aethersx2/aethersx2")
_AETHERSX2_LIBS: Final = Path("/usr/aethersx2/libs")
# Not batocera's usual CONFIGS ('configs', no dot) - the binary resolves its
# own DataRoot Directory to $HOME/.config/aethersx2 by itself (confirmed via
# its own startup log during the 2026-08-16 smoke test), so we write the ini
# to wherever it actually looks rather than fighting that default.
_AETHERSX2_CONFIG: Final = HOME / ".config" / "aethersx2"
_AETHERSX2_BIOS: Final = BIOS / "ps2"


class Aethersx2Generator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "aethersx2",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_ESC",
                "pause": "KEY_ESC",
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        configureINI(_AETHERSX2_CONFIG, system, playersControllers)
        linkBios(_AETHERSX2_CONFIG / "bios")

        commandArray = [str(_AETHERSX2_BIN), "-bigpicture", "-fullscreen", str(rom)]

        envcmd: dict[str, str] = {
            "QT_QPA_PLATFORM": "wayland",
            "QT_PLUGIN_PATH": "/usr/lib/qt6/plugins",
            "LD_LIBRARY_PATH": f"{_AETHERSX2_LIBS}:/usr/lib",
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
        }

        return Command.Command(array=commandArray, env=envcmd)


def linkBios(bios_dir: Path) -> None:
    mkdir_if_not_exists(bios_dir)
    if not _AETHERSX2_BIOS.is_dir():
        return
    for f in _AETHERSX2_BIOS.glob("*.bin"):
        dest = bios_dir / f.name
        if not dest.exists():
            dest.symlink_to(f)


def configureINI(config_directory: Path, system: Emulator, playersControllers: Controllers) -> None:
    ini_file = config_directory / "inis" / "PCSX2.ini"
    mkdir_if_not_exists(ini_file.parent)

    cfg = CaseSensitiveConfigParser(interpolation=None)
    if ini_file.is_file():
        cfg.read(ini_file)

    if not cfg.has_section("UI"):
        cfg.add_section("UI")
    # Without this, AetherSX2's own settings-version check treats the ini as
    # missing/wrong-version and shows a "Settings failed to load... reset to
    # defaults?" prompt on every launch - same key pcsx2Generator.py already
    # sets for the mainline pcsx2-qt build, just missing here.
    cfg.set("UI", "SettingsVersion", "1")
    cfg.set("UI", "StartFullscreen", "true")
    cfg.set("UI", "ConfirmShutdown", "false")
    cfg.set("UI", "HideMouseCursor", "true")

    if not cfg.has_section("EmuCore/GS"):
        cfg.add_section("EmuCore/GS")
    # Default (Auto=-1) tries OpenGL first on this fork, which fails outright
    # in our headless/Wayland-only environment (no real GLX acceleration) -
    # default to Vulkan, matching both ROCKNIX's own RK3566 default and the
    # exact config this was smoke-tested with (see project_odroid_retro.md,
    # 2026-08-16 AetherSX2 section). Software (13) is left available as a
    # user-selectable fallback since it doesn't need a GPU device at all.
    cfg.set("EmuCore/GS", "Renderer", system.config.get("aethersx2_gfxbackend", "14"))
    cfg.set("EmuCore/GS", "upscale_multiplier", system.config.get("aethersx2_resolution", "1"))
    cfg.set("EmuCore/GS", "OsdShowFPS", "true" if system.config.show_fps else "false")

    ## [InputSources]
    if not cfg.has_section("InputSources"):
        cfg.add_section("InputSources")
    cfg.set("InputSources", "Keyboard", "true")
    cfg.set("InputSources", "Mouse", "true")
    cfg.set("InputSources", "SDL", "true")

    ## [Pad1]/[Pad2] - the binary's own bundled default ini maps every pad
    # input to a keyboard key (confirmed live: buttons did nothing on a real
    # gamepad, only the keyboard worked, until this was added) - map to the
    # actual connected SDL controllers instead, same scheme pcsx2Generator
    # already uses successfully on this board for the sibling pcsx2 package.
    for section_name in ("Pad1", "Pad2", "Pad3", "Pad4"):
        if cfg.has_section(section_name):
            cfg.remove_section(section_name)

    for nplayer, pad in enumerate(playersControllers, start=1):
        if nplayer > 2:
            break
        pad_num = f"Pad{nplayer}"
        sdl_num = f"SDL-{pad.index}"
        cfg.add_section(pad_num)
        cfg.set(pad_num, "Type", "DualShock2")
        cfg.set(pad_num, "InvertL", "0")
        cfg.set(pad_num, "InvertR", "0")
        cfg.set(pad_num, "Deadzone", "0")
        cfg.set(pad_num, "AxisScale", "1.33")
        cfg.set(pad_num, "TriggerDeadzone", "0")
        cfg.set(pad_num, "TriggerScale", "1")
        cfg.set(pad_num, "LargeMotorScale", "1")
        cfg.set(pad_num, "SmallMotorScale", "1")
        cfg.set(pad_num, "ButtonDeadzone", "0")
        cfg.set(pad_num, "PressureModifier", "0.5")
        cfg.set(pad_num, "Up", f"{sdl_num}/DPadUp")
        cfg.set(pad_num, "Right", f"{sdl_num}/DPadRight")
        cfg.set(pad_num, "Down", f"{sdl_num}/DPadDown")
        cfg.set(pad_num, "Left", f"{sdl_num}/DPadLeft")
        # This fork's SDLInputSource predates PCSX2's later switch to
        # position-based "FaceNorth/FaceEast/FaceSouth/FaceWest" binding
        # names (what the sibling pcsx2 package uses) - it still expects the
        # older Nintendo-layout "A/B/X/Y" semantic names. Confirmed live: the
        # newer names silently bind to nothing (D-pad/sticks worked fine
        # since those names didn't change, only face buttons did no-input).
        # Values taken verbatim from ROCKNIX's own real-hardware-validated
        # RK3566 default ini (same aethersx2-sa binary, same input source).
        cfg.set(pad_num, "Triangle", f"{sdl_num}/X")
        cfg.set(pad_num, "Circle", f"{sdl_num}/A")
        cfg.set(pad_num, "Cross", f"{sdl_num}/B")
        cfg.set(pad_num, "Square", f"{sdl_num}/Y")
        cfg.set(pad_num, "Select", f"{sdl_num}/Back")
        cfg.set(pad_num, "Start", f"{sdl_num}/Start")
        cfg.set(pad_num, "L1", f"{sdl_num}/LeftShoulder")
        cfg.set(pad_num, "L2", f"{sdl_num}/+LeftTrigger")
        cfg.set(pad_num, "R1", f"{sdl_num}/RightShoulder")
        cfg.set(pad_num, "R2", f"{sdl_num}/+RightTrigger")
        cfg.set(pad_num, "L3", f"{sdl_num}/LeftStick")
        cfg.set(pad_num, "R3", f"{sdl_num}/RightStick")
        cfg.set(pad_num, "LUp", f"{sdl_num}/-LeftY")
        cfg.set(pad_num, "LRight", f"{sdl_num}/+LeftX")
        cfg.set(pad_num, "LDown", f"{sdl_num}/+LeftY")
        cfg.set(pad_num, "LLeft", f"{sdl_num}/-LeftX")
        cfg.set(pad_num, "RUp", f"{sdl_num}/-RightY")
        cfg.set(pad_num, "RRight", f"{sdl_num}/+RightX")
        cfg.set(pad_num, "RDown", f"{sdl_num}/+RightY")
        cfg.set(pad_num, "RLeft", f"{sdl_num}/-RightX")
        cfg.set(pad_num, "Analog", f"{sdl_num}/Guide")
        cfg.set(pad_num, "LargeMotor", f"{sdl_num}/LargeMotor")
        cfg.set(pad_num, "SmallMotor", f"{sdl_num}/SmallMotor")

    with ini_file.open("w") as f:
        cfg.write(f)
