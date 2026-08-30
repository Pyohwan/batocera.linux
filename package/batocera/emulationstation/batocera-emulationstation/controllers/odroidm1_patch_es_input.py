#!/usr/bin/env python3
# Appends the ODROID-M1-specific additions to the installed es_input.cfg
# (SHAKS S6b default gamepad mapping + keyboard hotkey bound to the same key
# as select) without touching the rest of upstream's controller database, so
# future upstream mapping additions/updates to this file survive untouched.
import sys

path = sys.argv[1]
with open(path) as f:
    text = f.read()

OLD_KB = '<input name="select" type="key" id="8" value="1" />'
assert OLD_KB in text, "es_input.cfg: keyboard select binding not found, upstream layout changed"
assert "SHAKS S6b" not in text, "es_input.cfg: SHAKS S6b entry already present, drop this hook"

NEW_KB = OLD_KB + '\n\t\t<input name="hotkey" type="key" id="8" value="1" />'
text = text.replace(OLD_KB, NEW_KB, 1)

SHAKS_BLOCK = '''\t<inputConfig type="joystick" deviceName="SHAKS S6b 52e1 Win-Mac" deviceGUID="050000005e0400008e02000030110000">
\t\t<input name="a" type="button" id="1" value="1" code="305" />
\t\t<input name="b" type="button" id="0" value="1" code="304" />
\t\t<input name="down" type="hat" id="0" value="4" />
\t\t<input name="hotkey" type="button" id="6" value="1" code="314" />
\t\t<input name="joystick1left" type="axis" id="0" value="-1" code="0" />
\t\t<input name="joystick1up" type="axis" id="1" value="-1" code="1" />
\t\t<input name="joystick2left" type="axis" id="3" value="-1" code="3" />
\t\t<input name="joystick2up" type="axis" id="4" value="-1" code="4" />
\t\t<input name="l2" type="axis" id="2" value="1" code="2" />
\t\t<input name="l3" type="button" id="9" value="1" code="317" />
\t\t<input name="left" type="hat" id="0" value="8" />
\t\t<input name="pagedown" type="button" id="5" value="1" code="311" />
\t\t<input name="pageup" type="button" id="4" value="1" code="310" />
\t\t<input name="r2" type="axis" id="5" value="1" code="5" />
\t\t<input name="r3" type="button" id="10" value="1" code="318" />
\t\t<input name="right" type="hat" id="0" value="2" />
\t\t<input name="select" type="button" id="6" value="1" code="314" />
\t\t<input name="start" type="button" id="7" value="1" code="315" />
\t\t<input name="up" type="hat" id="0" value="1" />
\t\t<input name="x" type="button" id="3" value="1" code="308" />
\t\t<input name="y" type="button" id="2" value="1" code="307" />
\t</inputConfig>
'''

CLOSING_TAG = "</inputList>"
assert text.rstrip().endswith(CLOSING_TAG), "es_input.cfg: unexpected trailing structure, upstream layout changed"
insert_at = text.rstrip().rfind(CLOSING_TAG)
text = text.rstrip()[:insert_at] + SHAKS_BLOCK + CLOSING_TAG + "\n"

with open(path, "w") as f:
    f.write(text)
