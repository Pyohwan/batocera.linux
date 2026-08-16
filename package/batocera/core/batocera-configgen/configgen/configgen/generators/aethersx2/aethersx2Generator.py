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
        configureINI(_AETHERSX2_CONFIG, system)
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


def configureINI(config_directory: Path, system: Emulator) -> None:
    ini_file = config_directory / "inis" / "PCSX2.ini"
    mkdir_if_not_exists(ini_file.parent)

    cfg = CaseSensitiveConfigParser(interpolation=None)
    if ini_file.is_file():
        cfg.read(ini_file)

    if not cfg.has_section("UI"):
        cfg.add_section("UI")
    cfg.set("UI", "StartFullscreen", "true")
    cfg.set("UI", "ConfirmShutdown", "false")
    cfg.set("UI", "HideMouseCursor", "true")

    if not cfg.has_section("EmuCore/GS"):
        cfg.add_section("EmuCore/GS")
    # Auto (-1) tries OpenGL first on this fork, which fails outright in our
    # headless/Wayland-only environment (no real GLX acceleration) - force
    # Vulkan, matching both ROCKNIX's own RK3566 default and the exact
    # config this was smoke-tested with (see project_odroid_retro.md,
    # 2026-08-16 AetherSX2 section).
    cfg.set("EmuCore/GS", "Renderer", "14")
    cfg.set("EmuCore/GS", "upscale_multiplier", system.config.get("aethersx2_resolution", "1"))

    with ini_file.open("w") as f:
        cfg.write(f)
