#!/usr/bin/env python3
"""从 Theme.generated.swift 的字段表生成 PaletteOverride.swift（BarlyPalette.replacing）。
身份重新生成、字段有增减时重跑：python3 apple/scripts/gen-palette-override.py"""
import re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent / "BarlyKit/Sources/BarlyKit"
gen = (root / "Generated/Theme.generated.swift").read_text()
struct = gen[gen.index("public struct BarlyPalette"):gen.index("public static let light")]
fields = re.findall(r"public let (\w+): Color", struct)
cases = "\n".join(f"        case {f}" for f in fields)
args = ",\n".join(f"            {f}: o[.{f}] ?? {f}" for f in fields)
out = f"""// 由 apple/scripts/gen-palette-override.py 生成：身份重新生成后重跑，不要手改
import SwiftUI

public extension BarlyPalette {{
    /// 色板里的每一个颜色
    enum Key: String, CaseIterable, Sendable {{
{cases}
    }}

    /// 以这套色板为底，换掉给出的颜色（app 主题用：外壳换色，代码高亮、图表色保留身份的）
    func replacing(_ o: [Key: Color]) -> BarlyPalette {{
        BarlyPalette(
{args}
        )
    }}
}}
"""
(root / "Theme/PaletteOverride.swift").write_text(out)
print(f"✓ {len(fields)} 个颜色 → Theme/PaletteOverride.swift")
