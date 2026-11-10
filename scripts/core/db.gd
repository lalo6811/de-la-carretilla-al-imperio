extends Node
## Base de datos del juego: materiales, mejoras, vehiculos, clientes.
## Todos los precios en pesos del juego. Ajusta aqui el balance.

# source: "mine" = se trae de la mina, "supplier" = se compra al proveedor
const ITEMS := {
	"arena":    {"unit": "bote", "source": "mine", "cost": 4, "sell": 9, "lvl": 1, "cat": "mat"},
	"grava":    {"unit": "bote", "source": "mine", "cost": 5, "sell": 11, "lvl": 1, "cat": "mat"},
	"tepetate": {"unit": "bote", "source": "mine", "cost": 3, "sell": 7, "lvl": 2, "cat": "mat"},
	"piedra":   {"unit": "bote", "source": "mine", "cost": 7, "sell": 15, "lvl": 3, "cat": "mat", "needs": "pico"},
	"tezontle": {"unit": "bote", "source": "mine", "cost": 9, "sell": 19, "lvl": 6, "cat": "mat", "needs": "pico"},
	"cemento":  {"unit": "bulto", "source": "supplier", "cost": 120, "sell": 165, "lvl": 1, "cat": "mat"},
	"cal":      {"unit": "bulto", "source": "supplier", "cost": 60, "sell": 85, "lvl": 1, "cat": "mat"},
	"clavos":   {"unit": "kg", "source": "supplier", "cost": 30, "sell": 45, "lvl": 1, "cat": "mat"},
	"tabique":  {"unit": "pza", "source": "supplier", "cost": 4, "sell": 7, "lvl": 2, "cat": "mat"},
	"alambre":  {"unit": "kg", "source": "supplier", "cost": 25, "sell": 38, "lvl": 2, "cat": "mat"},
	"martillo": {"unit": "pza", "source": "supplier", "cost": 90, "sell": 140, "lvl": 2, "cat": "tool"},
	"pala":     {"unit": "pza", "source": "supplier", "cost": 120, "sell": 180, "lvl": 2, "cat": "tool"},
	"varilla":  {"unit": "pza", "source": "supplier", "cost": 110, "sell": 155, "lvl": 3, "cat": "mat"},
	"block":    {"unit": "pza", "source": "supplier", "cost": 12, "sell": 19, "lvl": 3, "cat": "mat"},
	"cuchara":  {"unit": "pza", "source": "supplier", "cost": 60, "sell": 95, "lvl": 3, "cat": "tool"},
	"tubo":     {"unit": "tramo", "source": "supplier", "cost": 70, "sell": 105, "lvl": 4, "cat": "mat"},
	"yeso":     {"unit": "bulto", "source": "supplier", "cost": 80, "sell": 118, "lvl": 4, "cat": "mat"},
	"cinta":    {"unit": "pza", "source": "supplier", "cost": 50, "sell": 82, "lvl": 4, "cat": "tool"},
	"pintura":  {"unit": "cubeta", "source": "supplier", "cost": 450, "sell": 630, "lvl": 5, "cat": "mat"},
	"carretilla": {"unit": "pza", "source": "supplier", "cost": 900, "sell": 1300, "lvl": 6, "cat": "tool"},
	"impermeabilizante": {"unit": "cubeta", "source": "supplier", "cost": 700, "sell": 960, "lvl": 7, "cat": "mat"},
	"azulejo":  {"unit": "caja", "source": "supplier", "cost": 220, "sell": 315, "lvl": 8, "cat": "mat"},
	"castillo": {"unit": "pza", "source": "supplier", "cost": 180, "sell": 255, "lvl": 9, "cat": "mat"},
	"taladro":  {"unit": "pza", "source": "supplier", "cost": 900, "sell": 1320, "lvl": 10, "cat": "tool"},
}
const ITEM_ORDER := ["arena", "grava", "tepetate", "piedra", "tezontle", "cemento", "cal", "clavos", "tabique", "alambre",
	"martillo", "pala", "varilla", "block", "cuchara", "tubo", "yeso", "cinta", "pintura", "carretilla",
	"impermeabilizante", "azulejo", "castillo", "taladro"]

# Etapas del local. cap = espacio de inventario, queue = clientes en fila, spawn = multiplicador de clientes
# patio = granel (arena, grava...), shelf = anaqueles/bodega (bultos, piezas, cubetas)
# queue = lugares en la fila, demand = clientes extra por dia
const SHOP_STAGES := [
	{"cost": 0, "lvl": 1, "patio": 24, "shelf": 16, "queue": 1, "demand": 0},       # 0 abandonado (se limpia)
	{"cost": 0, "lvl": 1, "patio": 30, "shelf": 20, "queue": 2, "demand": 1},       # 1 limpio
	{"cost": 500, "lvl": 2, "patio": 36, "shelf": 45, "queue": 2, "demand": 2},     # 2 anaqueles nuevos
	{"cost": 1500, "lvl": 3, "patio": 50, "shelf": 60, "queue": 3, "demand": 3},    # 3 pintura y letrero
	{"cost": 4000, "lvl": 5, "patio": 70, "shelf": 90, "queue": 3, "demand": 5},    # 4 mostrador grande
	{"cost": 12000, "lvl": 7, "patio": 110, "shelf": 140, "queue": 4, "demand": 7}, # 5 ampliacion
	{"cost": 30000, "lvl": 9, "patio": 150, "shelf": 360, "queue": 4, "demand": 9}, # 6 bodega al lado
	{"cost": 80000, "lvl": 12, "patio": 600, "shelf": 420, "queue": 4, "demand": 11},# 7 patio de carga
	{"cost": 200000, "lvl": 16, "patio": 1200, "shelf": 900, "queue": 4, "demand": 14}, # 8 gran casa de materiales
]

# Casa: energia maxima y recuperacion por minuto mientras juegas (atender cuesta 1, ir a la mina 3)
const HOUSE_STAGES := [
	{"cost": 0, "lvl": 1, "energy": 20, "regen": 1.0},
	{"cost": 400, "lvl": 1, "energy": 25, "regen": 1.2},
	{"cost": 2000, "lvl": 3, "energy": 30, "regen": 1.4},
	{"cost": 8000, "lvl": 6, "energy": 36, "regen": 1.7},
	{"cost": 25000, "lvl": 9, "energy": 43, "regen": 2.0},
	{"cost": 90000, "lvl": 13, "energy": 50, "regen": 2.5},
]

# Transporte casa-local (solo estetico)
const TRANSPORTS := {
	"pie":   {"cost": 0, "bolts": 0, "lvl": 1, "tex": ""},
	"bici":  {"cost": 800, "bolts": 0, "lvl": 2, "tex": "tr_bike"},
	"moto":  {"cost": 6000, "bolts": 0, "lvl": 6, "tex": "tr_moto"},
	"vocho": {"cost": 20000, "bolts": 120, "lvl": 10, "tex": "tr_vocho"},
}
const TRANSPORT_ORDER := ["pie", "bici", "moto", "vocho"]

# Vehiculos para ir a la mina
# carretilla: tiers (se mejora), las demas se compran (puedes tener varias)
const WHEELBARROW_TIERS := [
	{"cap": 6, "time": 30, "cost": 0, "lvl": 1},
	{"cap": 10, "time": 26, "cost": 300, "lvl": 1},
	{"cap": 16, "time": 22, "cost": 1200, "lvl": 3},
]
const VEHICLES := {
	"wheelbarrow": {"tex": "veh_wheelbarrow_0", "cap": 6, "time": 30, "cost": 600, "lvl": 2, "gas": 0, "driver": 60, "max": 3, "energy": 3},
	"pickup":   {"tex": "veh_pickup", "cap": 40, "time": 40, "cost": 6000, "lvl": 5, "gas": 40, "driver": 180, "max": 3, "energy": 2, "shop": 3},
	"truck":    {"tex": "veh_truck", "cap": 120, "time": 55, "cost": 35000, "lvl": 10, "gas": 150, "driver": 350, "max": 3, "energy": 2, "shop": 6},
	"bigtruck": {"tex": "veh_bigtruck", "cap": 320, "time": 70, "cost": 150000, "lvl": 15, "gas": 420, "driver": 600, "max": 2, "energy": 2, "shop": 7},
}
const VEHICLE_ORDER := ["wheelbarrow", "pickup", "truck", "bigtruck"]

# Herramientas propias (mejoras permanentes)
const TOOLS := {
	"guantes":     {"cost": 250, "lvl": 2},   # -1 energia por viaje
	"calculadora": {"cost": 400, "lvl": 2},   # cobras 5% mas
	"pico":        {"cost": 700, "lvl": 3},   # desbloquea piedra y tezontle
	"radio":       {"cost": 900, "lvl": 4},   # +1 cliente al dia
	"pala_pro":    {"cost": 2500, "lvl": 5},  # +25% carga en todos los viajes
	"gps":         {"cost": 9000, "lvl": 8},  # viajes 15% mas rapidos
}
const TOOL_ORDER := ["guantes", "calculadora", "pico", "radio", "pala_pro", "gps"]

# Empleada: tiene su propia caja y fila; atiende pedidos chicos sola (tambien con la app cerrada)
# quota = clientes de su fila por dia, every = segundos por cliente
const CLERK := {"hire": 1500, "lvl": 4, "salary": 120, "quota": 4, "every": 9.0}
const CLERK2 := {"hire": 9000, "lvl": 8, "salary": 260, "quota": 4, "every": 6.0}
const OFFLINE_HOURS := [ {"hours": 2, "cost": 0}, {"hours": 4, "cost": 3000}, {"hours": 8, "cost": 12000}, {"hours": 12, "cost": 40000} ]
const OWN_MINE := {"cost": 250000, "lvl": 15, "price_mult": 0.4}  # con mina propia el material cuesta 40%

# Clientes
const CUSTOMER_TYPES := {
	"vecino":     {"lvl": 1, "items": [1, 2], "qty": [1, 3], "mult": 1.0, "patience": 34, "haggle": 0.25},
	"albanil":    {"lvl": 2, "items": [1, 3], "qty": [2, 6], "mult": 1.0, "patience": 30, "haggle": 0.2},
	"plomero":    {"lvl": 4, "items": [1, 3], "qty": [1, 5], "mult": 1.05, "patience": 30, "haggle": 0.15},
	"maestro":    {"lvl": 5, "items": [2, 4], "qty": [4, 12], "mult": 1.05, "patience": 36, "haggle": 0.25},
	"ingeniero":  {"lvl": 8, "items": [3, 5], "qty": [8, 30], "mult": 1.1, "patience": 40, "haggle": 0.15},
	"constructora": {"lvl": 12, "items": [3, 5], "qty": [20, 80], "mult": 1.15, "patience": 45, "haggle": 0.3},
}
const CUSTOMER_PREFS := {
	"vecino": ["arena", "cemento", "cal", "clavos", "pintura", "tubo", "martillo", "yeso", "cinta", "grava", "impermeabilizante"],
	"albanil": ["cemento", "arena", "grava", "cal", "tabique", "varilla", "alambre", "block", "cuchara", "pala", "tepetate", "castillo"],
	"plomero": ["tubo", "cemento", "cinta", "yeso", "clavos", "taladro", "alambre"],
	"maestro": ["cemento", "arena", "grava", "varilla", "block", "tabique", "piedra", "castillo", "alambre", "cal"],
	"ingeniero": ["cemento", "varilla", "grava", "arena", "block", "castillo", "impermeabilizante", "azulejo", "piedra", "tezontle"],
	"constructora": ["cemento", "varilla", "grava", "arena", "block", "tabique", "piedra", "tezontle", "castillo", "azulejo"],
}
const NAMES_M := ["Juan", "José", "Luis", "Carlos", "Miguel", "Pedro", "Jorge", "Raúl", "Toño", "Memo", "Lalo", "Chema", "Pancho", "Rafa", "Héctor", "Beto", "Nacho", "Gerardo", "Iván", "Rubén", "Fer", "Óscar", "Saúl", "Tomás"]
const NAMES_F := ["María", "Lupita", "Rosa", "Ana", "Carmen", "Sofía", "Paty", "Lety", "Elena", "Vero", "Karla", "Mónica", "Juana", "Silvia", "Irma", "Gaby", "Norma", "Rocío", "Alma", "Diana"]

# Clientes fijos que regresan de vez en cuando (look fijo)
const REGULARS := [
	{"id": "chuy", "every": 3, "name": "Don Chuy", "type": "albanil", "lvl": 1,
		"look": {"gender": "m", "skin": 2, "face": "bigote", "hair": "rapado", "hair_color": 5, "acc": "gorra", "top": "playera", "top_color": 5, "pants": "pantalon", "pants_color": 3, "shoes": 1}},
	{"id": "mari", "every": 3, "name": "Doña Mari", "type": "vecino", "lvl": 1,
		"look": {"gender": "f", "skin": 1, "face": "feliz", "hair": "chongo", "hair_color": 5, "acc": "ninguno", "top": "camisa", "top_color": 7, "pants": "falda", "pants_color": 2, "shoes": 0}},
	{"id": "beto", "every": 4, "name": "Beto el plomero", "type": "plomero", "lvl": 4,
		"look": {"gender": "m", "skin": 3, "face": "normal", "hair": "corto", "hair_color": 0, "acc": "gorra", "top": "overol", "top_color": 3, "pants": "pantalon", "pants_color": 0, "shoes": 0}},
	{"id": "paty", "every": 5, "name": "Maestra Paty", "type": "maestro", "lvl": 5,
		"look": {"gender": "f", "skin": 2, "face": "serio", "hair": "melena", "hair_color": 0, "acc": "casco", "top": "chaleco", "top_color": 6, "pants": "pantalon", "pants_color": 1, "shoes": 1}},
	{"id": "ramirez", "every": 7, "name": "Ing. Ramírez", "type": "ingeniero", "lvl": 8,
		"look": {"gender": "m", "skin": 0, "face": "serio", "hair": "de_lado", "hair_color": 2, "acc": "lentes", "top": "camisa", "top_color": 2, "pants": "pantalon", "pants_color": 4, "shoes": 1}},
]

# Cosmeticos que se compran (lo que no esta aqui es gratis)
# price_type: money / bolts / ad / pack
const COSMETICS := {
	"acc:gorra": {"type": "money", "price": 300},
	"acc:casco": {"type": "money", "price": 1200},
	"acc:sombrero": {"type": "money", "price": 800},
	"acc:paliacate": {"type": "ad", "price": 1},
	"acc:lentes_oscuros": {"type": "bolts", "price": 20},
	"top:chaleco": {"type": "money", "price": 600},
	"top:sudadera": {"type": "money", "price": 450},
	"top:overol_dorado": {"type": "pack", "price": 0},
	"hair_color:6": {"type": "bolts", "price": 15},
}

# Productos de dinero real (simulados hasta conectar Google Play Billing)
const PRODUCTS := {
	"starter_pack": {"price": "$49 MXN", "money": 5000, "bolts": 100, "unlock": ["top:overol_dorado", "tr:bici"]},
	"no_ads": {"price": "$79 MXN"},
	"bolts_small": {"price": "$19 MXN", "bolts": 100},
	"bolts_mid": {"price": "$89 MXN", "bolts": 550},
	"bolts_big": {"price": "$179 MXN", "bolts": 1200},
}

# Pedidos con proyecto: la frase del cliente va con lo que pide
const PROJECTS := {
	"vecino": [
		{"id": "pintar", "items": ["pintura", "cal", "cinta", "yeso"]},
		{"id": "resanar", "items": ["yeso", "cal", "cemento", "cinta"]},
		{"id": "jardin", "items": ["tepetate", "arena", "grava"]},
		{"id": "azotea", "items": ["impermeabilizante", "cemento", "arena"]},
		{"id": "puerta", "items": ["clavos", "martillo", "alambre"]},
		{"id": "pisito", "items": ["cemento", "arena", "grava"]},
	],
	"albanil": [
		{"id": "barda", "items": ["tabique", "cemento", "cal", "arena", "block"]},
		{"id": "colado", "items": ["cemento", "grava", "arena", "varilla", "alambre"]},
		{"id": "castillos", "items": ["varilla", "alambre", "castillo", "cemento", "grava"]},
		{"id": "aplanado", "items": ["cal", "arena", "cemento", "cuchara"]},
		{"id": "relleno", "items": ["tepetate", "grava", "arena", "pala"]},
	],
	"plomero": [
		{"id": "bano", "items": ["tubo", "cemento", "cinta", "azulejo"]},
		{"id": "fuga", "items": ["tubo", "cinta", "yeso", "taladro"]},
		{"id": "drenaje", "items": ["tubo", "cemento", "grava", "alambre"]},
	],
	"maestro": [
		{"id": "cuarto", "items": ["block", "cemento", "arena", "grava", "varilla", "castillo"]},
		{"id": "cimientos", "items": ["piedra", "cemento", "arena", "grava", "varilla"]},
		{"id": "firme", "items": ["cemento", "arena", "grava", "tepetate"]},
		{"id": "segundo_piso", "items": ["tabique", "cal", "cemento", "varilla", "alambre"]},
	],
	"ingeniero": [
		{"id": "losa", "items": ["cemento", "varilla", "grava", "arena", "alambre"]},
		{"id": "fachada", "items": ["tezontle", "cemento", "azulejo", "impermeabilizante", "pintura"]},
		{"id": "obra", "items": ["block", "castillo", "varilla", "cemento", "grava"]},
	],
	"constructora": [
		{"id": "fraccionamiento", "items": ["block", "cemento", "varilla", "grava", "arena", "castillo"]},
		{"id": "empedrado", "items": ["piedra", "tezontle", "grava", "tepetate", "cemento"]},
		{"id": "acabados", "items": ["azulejo", "impermeabilizante", "pintura", "yeso"]},
	],
}

# Logros: stat a revisar, metas y tornillos de premio por meta
const ACHIEVEMENTS := [
	{"id": "served", "goals": [10, 100, 500, 1000, 5000], "bolts": [5, 10, 20, 40, 80]},
	{"id": "earned", "goals": [10000, 100000, 1000000], "bolts": [10, 25, 60]},
	{"id": "trips", "goals": [10, 100, 500], "bolts": [5, 15, 40]},
	{"id": "deliveries", "goals": [1, 100], "bolts": [5, 30]},
	{"id": "perfect_days", "goals": [1, 10, 50], "bolts": [5, 20, 50]},
	{"id": "regulars", "goals": [5], "bolts": [25]},
	{"id": "shop_max", "goals": [1], "bolts": [100]},
	{"id": "house_max", "goals": [1], "bolts": [60]},
	{"id": "own_mine", "goals": [1], "bolts": [100]},
	{"id": "fleet_all", "goals": [1], "bolts": [40]},
	{"id": "streak", "goals": [3, 7, 30], "bolts": [10, 25, 80]},
]

# Calendario: el dia 1 es lunes. Proveedor pasa lunes, miercoles y viernes. La mina cierra en domingo.
const SUPPLIER_DAYS := [0, 2, 4]
const MINE_CLOSED_DAYS := [6]
const URGENT_MULT := 1.2
const ENCARGO_DEPOSIT := 0.3
const LIGHT_BILL_BASE := 50
const LIGHT_BILL_PER_STAGE := 60
const SERVE_ENERGY := 1

const DELIVERY_CHANCE := {"maestro": 0.3, "ingeniero": 0.5, "constructora": 0.75}
const AD_DAILY_LIMITS := {"energy": 5, "offline_double": 3, "trip_skip": 5, "visitor": 8, "bolts": 5, "cosmetic": 10}

# Dia de juego: ya no hay reloj que corra. El dia avanza por fases (manana, jornada, cierre)
const DAY_START := 8 * 60      # (solo para partidas viejas)

func xp_for_level(l: int) -> int:
	return int(round(50.0 * pow(float(l), 1.5)))

func space_kind(id: String) -> String:
	## Lo de la mina va al patio; lo demas, a los anaqueles
	return "patio" if ITEMS[id]["source"] == "mine" else "shelf"

func item_unlocked(id: String, level: int, tools: Dictionary) -> bool:
	var it: Dictionary = ITEMS[id]
	if level < int(it["lvl"]):
		return false
	if it.has("needs") and not tools.get(it["needs"], false):
		return false
	return true
