# Idle Slayer V3 ⚔️🪙

Un juego 2D Auto-Runner e Idle RPG desarrollado en **Godot Engine 4** con estilo retro pixel art de 16-bit.

---

## 🎮 Características Actuales

- **Espadachín Articulado (Shadow Knight):**
  - **Carrera Fluida (15 FPS):** Inclinación atlética hacia adelante (2.5°), pisadas rítmicas con estallidos de polvo y estela carmesí (*ghost trail*) con *Object Pooling*.
  - **Salto Dinámico en 3 Fases:**
    - 🟢 *Salto Corto:* Toque rápido (~100px).
    - 🟡 *Salto Medio:* Mantener presionado (~225px) con voltereta aérea (*somersault* 360°).
    - 🟣 *Salto Alto:* Mantener máximo tiempo (~350px hasta el nivel de la luna) con doble voltereta (720°) y aterrizaje erguido estabilizado.
  - **Ataque Articulado:** Tajo con estocada frontal (+6px de inercia), soplido de polvo en suelo, hitbox calibrada y medialuna completa de plasma cian sin recortes.

- **Monedas de Bronce y Generación:**
  - Monedas con rotación cilíndrica 3D, bisel metálico y destellos de resplandor (*sparkle glints*).
  - Spawner cada 5 segundos con patrones aleatorios de 1, 2 y 3 monedas (a ras de suelo, arco de salto medio y arco ascendente hacia la luna).
  - Recolección al paso o al cortar con el filo de la espada, con estallido de chispas doradas y *Object Pooling* (Zero Garbage Collection).

- **HUD Centralizado:**
  - Contador de monedas ubicado en la mitad superior de la pantalla con badge cobrizo y animación de pulso al recolectar.
  - Badge de estado dinámico en tiempo real (`CORRIENDO`, `SALTO CORTO/MEDIO/ALTO`, `¡ATAQUE!`).

- **Modal de la Tienda y Mejoras:**
  - Ventana modal con fondo translúcido y bordes metálicos de bronce.
  - **Franja 1 (Multiplicadores de compra):** Selector rápido de `1x`, `10x`, `50x`, `100x` y `MAX` con selección activa iluminada.
  - **Franja 2 (5 Pestañas de Menú):**
    1. `⚔️ EQUIPO` (Armas y armaduras)
    2. `⚡ MEJORAS` (Multiplicadores pasivos de monedas y velocidad)
    3. `📜 MISIONES` (Logros y retos)
    4. `🔮 ASCENSIÓN` (Árbol de almas y sabiduría ancestral)
    5. `⚙️ AJUSTES` (Configuración y estadísticas)

---

## 🕹️ Controles

| Acción | Teclado | Ratón / Táctil |
| :--- | :--- | :--- |
| **Salto** | `Espacio`, `W`, `Flecha Arriba` | Clic en mitad izquierda o botón `SALTO` |
| **Ataque** | `Z`, `X`, `J` | Clic derecho o botón `ATAQUE` |
| **Tienda** | `B`, `E` | Botón `🛒 TIENDA` |

---

## 🛠️ Tecnologías y Arquitectura

- **Motor:** Godot Engine 4.7.2 (Exportación Web / WebAssembly / WebGL2).
- **Rendimiento:** *Object Pooling* para proyectiles, estelas y monedas (cero recolección de basura).
- **Estilo:** Pixel Art 16-bit arcade con paleta cálida y efectos lumínicos.
