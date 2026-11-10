# De la Carretilla al Imperio (v0.5.0, versión de prueba)

Juego idle de casa de materiales para Android hecho en **Godot 4.6** (renderer Compatibility, vertical 360x640).

## Cómo abrirlo
1. Instala Godot 4.3 (estable).
2. En Godot: **Importar** → selecciona `project.godot` de esta carpeta.
3. F5 para jugar en la computadora (la ventana simula un celular vertical).

## Instalar el APK en tu celular
- Pasa `carretilla.apk` al celular y ábrelo (acepta "instalar apps de origen desconocido").
- Está firmado con una llave de prueba (`carretilla.keystore`, alias `carretilla`, contraseña `carretilla123`).
  Para publicar en Play Store crea tu propia llave y guárdala muy bien.

## Exportar tú mismo a Android
1. Editor → Administrar plantillas de exportación → descargar las de 4.3.
2. Editor → Configuración del editor → Exportar → Android: ruta del Android SDK y del JDK 17.
3. Proyecto → Exportar → preset "Android" ya está creado → cambia la ruta del keystore a la tuya → Exportar proyecto.

## Estructura
- `scripts/core/db.gd`: **todo el balance** (precios, materiales, etapas del local y la casa, vehículos, herramientas, clientes, productos).
- `scripts/core/game_state.gd`: estado, guardado (3 ranuras en `user://`), economía, clientes, viajes, empleados, offline.
- `scripts/core/i18n.gd`: todos los textos en español e inglés.
- `scripts/core/art.gd`: personajes chibi 16x20 por capas (cuerpo, cara, cabello, accesorio, ropa), mismo sistema de filas de pixeles que Jessy's Rush.
- `scripts/core/monetization.gd`: anuncios y compras **simulados** (ver abajo).
- `scripts/screens/`: menú, ranuras, opciones, creador/clóset, intro.
- `scripts/game/`: pantalla de juego y escenarios (local, mina, casa).
- `assets/art/`: PNGs reemplazables (mismo nombre y tamaño). Se generan con `python3 tools/gen_art.py`.
- `assets/sfx/`: sonidos (wav, `python3 tools/gen_sfx.py`) y música (ogg, `python3 tools/gen_music.py`): `music_game.ogg` ~2 min estilo cumbia y `music_menu.ogg`.

## Cambios v0.5
- Sin reloj que presione: el día tiene mañana (mina y proveedor), jornada con una cantidad de clientes que varía cada día, y tarde (mejoras, ir a casa, dormir).
- Energía: atender cuesta 1, ir a la mina 3. Contratar gente cambia dinero por energía.
- Inventario en dos espacios: patio (granel de la mina) y anaqueles/bodega (lo del proveedor).
- Proveedor pasa lunes, miércoles y viernes; pedido urgente llega hoy pero cuesta 20% más. La mina cierra en domingo.
- Encargos con anticipo (el cliente regresa en dos días) y "Llévese lo que hay" para vender parte del pedido.
- Empleada con su propia caja y fila; despedir empleada y choferes.
- Despacho de vehículos, fichas para cambiar de vehículo en la carga y botón "Mandar por lo que falta".
- Pedidos con proyecto: lo que dice el cliente coincide con lo que pide.
- Logros con premio en tornillos; resumen del día con gastos por categoría; recibo de luz semanal.
- Mina propia: el material cuesta 40% (ya no es gratis). Si te quedas sin dinero, la mina te fía poquito.
- Escenarios que no se reinician al cambiar de lugar, minero que palea con las dos manos en cada montón, letras nítidas (MSDF).
- `godot --path . -- --balance` simula 22 días con un jugador automático para revisar el balance.

## Cambios v0.2
- Personajes nuevos: más grandes (22x42), proporciones normales, contorno de color.
- Vista nueva: fondo kraft, tarjetas crema, barras de madera, botones amarillo de seguridad.
- Día 1 guiado: el reloj no avanza, solo llegan Doña Mari y Don Chuy; los avisos van en el panel, no tapan el escenario.
- Fila sin tiempo: los clientes esperan; si la fila está llena, el nuevo se va. Día de ~9 min y clientes más espaciados.
- Música nueva más larga y distinta para menú y juego.

## Qué incluye
- Menú, 3 ranuras de guardado, guardado automático, opciones (idioma ES/EN, música, efectos, vibración).
- Creador de personaje hombre/mujer (piel, cara, cabello, color, accesorio, ropa, zapatos). Clóset en la casa con ropa que se compra con dinero, tornillos, anuncio o pack.
- Intro en viñetas (pierdes tu trabajo, la carta del abuelo, el local y la carretilla oxidada).
- Local por etapas: limpiar → anaqueles → pintura y letrero → mostrador grande → ampliación → bodega al lado → patio de carga → gran casa de materiales.
- Clientes armados al azar (aspecto, nombre, tipo y pedido) con semilla distinta por partida y por día, más clientes fijos (Don Chuy, Doña Mari, Beto el plomero, Maestra Paty, Ing. Ramírez). Regateo, paciencia y propina por servicio rápido.
- Inventario con espacio limitado, proveedor (compra inmediata, más caro) y mina (más barato).
- Mina: carretilla (3 niveles), camionetas, camiones de volteo y tractocamiones (varios de cada uno), choferes que viajan aunque no juegues (uno a la vez por vehículo, tú los mandas), comprar tu propia mina.
- Casa con 6 etapas (energía máxima y recuperación), dormir para pasar el día y pagar sueldos, transporte estético (a pie, bici, moto, vochito).
- Niveles y experiencia con desbloqueos.
- Empleada de mostrador: atiende cuando vas a la mina y vende mientras no juegas (tope de horas mejorable). Resumen de "Mientras no estabas" con opción de duplicar con anuncio.
- Visitante (tu compadre) que aparece cada ciertos minutos con un regalo a cambio de ver un anuncio.
- Tienda: pack inicial, pack sin anuncios, paquetes de tornillos de oro, premios gratis con anuncio (con límite diario).

## Conectar anuncios y compras reales
En `scripts/core/monetization.gd`:
- **AdMob**: instala el plugin "Godot AdMob" (poing-studios). En `show_rewarded()` cambia `_fake_ad()` por cargar y mostrar un RewardedAd; entrega la recompensa en el callback de "user earned reward". Necesitas tu App ID y los IDs de bloque.
- **Google Play Billing**: instala el plugin oficial "GodotGooglePlayBilling". En `purchase()` cambia la confirmación simulada por la compra real; entrega con `_grant(product_id)` cuando Google confirme. Los IDs (`starter_pack`, `no_ads`, `bolts_small`, `bolts_mid`, `bolts_big`) deben existir en Play Console.
- Con plugins hay que activar "Use Gradle Build" en el preset de exportación.

## Pruebas automáticas (en la compu)
- `godot --path . -- --autotest` recorre todas las pantallas y guarda capturas en `/tmp/shots`.
- `godot --path . -- --logictest` prueba los flujos (jornada, energía, inventario, proveedor, encargos, empleada, viajes, offline, logros, compras).
