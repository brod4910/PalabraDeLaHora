# Key forms for the hand-written cards (shown as the "Key forms" table, each row tappable to hear it).
# Verbs:      spanish | yo | tú | él / ella | past (yo)
# Gustar-type verbs use a mí / a ti / a él / ella labels instead.
# Nouns:      spanish | singular | plural          ("-" = no common form)
# Adjectives: spanish | masculine | feminine | plural   (feminine "=" → same for m. & f.)

VERBS = r"""
querer | quiero | quieres | quiere | quise
necesitar | necesito | necesitas | necesita | necesité
tener | tengo | tienes | tiene | tuve
ir | voy | vas | va | fui
poder | puedo | puedes | puede | pude
hablar | hablo | hablas | habla | hablé
comer | como | comes | come | comí
beber | bebo | bebes | bebe | bebí
hacer | hago | haces | hace | hice
saber | sé | sabes | sabe | supe
conocer | conozco | conoces | conoce | conocí
estar | estoy | estás | está | estuve
ser | soy | eres | es | fui
sentir | siento | sientes | siente | sentí
esperar | espero | esperas | espera | esperé
llegar | llego | llegas | llega | llegué
salir | salgo | sales | sale | salí
buscar | busco | buscas | busca | busqué
encontrar | encuentro | encuentras | encuentra | encontré
pensar | pienso | piensas | piensa | pensé
dormir | duermo | duermes | duerme | dormí
trabajar | trabajo | trabajas | trabaja | trabajé
aprender | aprendo | aprendes | aprende | aprendí
entender | entiendo | entiendes | entiende | entendí
recordar | recuerdo | recuerdas | recuerda | recordé
viajar | viajo | viajas | viaja | viajé
cocinar | cocino | cocinas | cocina | cociné
extrañar | extraño | extrañas | extraña | extrañé
vivir | vivo | vives | vive | viví
ver | veo | ves | ve | vi
dar | doy | das | da | di
decir | digo | dices | dice | dije
venir | vengo | vienes | viene | vine
llamar | llamo | llamas | llama | llamé
leer | leo | lees | lee | leí
escribir | escribo | escribes | escribe | escribí
comprar | compro | compras | compra | compré
pagar | pago | pagas | paga | pagué
ayudar | ayudo | ayudas | ayuda | ayudé
tomar | tomo | tomas | toma | tomé
jugar | juego | juegas | juega | jugué
preguntar | pregunto | preguntas | pregunta | pregunté
pedir | pido | pides | pide | pedí
contestar | contesto | contestas | contesta | contesté
empezar | empiezo | empiezas | empieza | empecé
terminar | termino | terminas | termina | terminé
volver | vuelvo | vuelves | vuelve | volví
cambiar | cambio | cambias | cambia | cambié
olvidar | olvido | olvidas | olvida | olvidé
perder | pierdo | pierdes | pierde | perdí
ganar | gano | ganas | gana | gané
mirar | miro | miras | mira | miré
escuchar | escucho | escuchas | escucha | escuché
caminar | camino | caminas | camina | caminé
descansar | descanso | descansas | descansa | descansé
limpiar | limpio | limpias | limpia | limpié
llevar | llevo | llevas | lleva | llevé
traer | traigo | traes | trae | traje
poner | pongo | pones | pone | puse
creer | creo | crees | cree | creí
parecer | parezco | pareces | parece | parecí
lograr | logro | logras | logra | logré
intentar | intento | intentas | intenta | intenté
darse cuenta | me doy cuenta | te das cuenta | se da cuenta | me di cuenta
acordarse | me acuerdo | te acuerdas | se acuerda | me acordé
quedarse | me quedo | te quedas | se queda | me quedé
preocuparse | me preocupo | te preocupas | se preocupa | me preocupé
enojarse | me enojo | te enojas | se enoja | me enojé
casarse | me caso | te casas | se casa | me casé
mudarse | me mudo | te mudas | se muda | me mudé
ahorrar | ahorro | ahorras | ahorra | ahorré
gastar | gasto | gastas | gasta | gasté
compartir | comparto | compartes | comparte | compartí
cuidar | cuido | cuidas | cuida | cuidé
elegir | elijo | eliges | elige | elegí
probar | pruebo | pruebas | prueba | probé
merecer | merezco | mereces | merece | merecí
apoyar | apoyo | apoyas | apoya | apoyé
dejar | dejo | dejas | deja | dejé
seguir | sigo | sigues | sigue | seguí
molestar | molesto | molestas | molesta | molesté
aprovechar | aprovecho | aprovechas | aprovecha | aproveché
cumplir | cumplo | cumples | cumple | cumplí
superar | supero | superas | supera | superé
suponer | supongo | supones | supone | supuse
fingir | finjo | finges | finge | fingí
arrepentirse | me arrepiento | te arrepientes | se arrepiente | me arrepentí
enterarse | me entero | te enteras | se entera | me enteré
aguantar | aguanto | aguantas | aguanta | aguanté
madrugar | madrugo | madrugas | madruga | madrugué
convivir | convivo | convives | convive | conviví
disfrutar | disfruto | disfrutas | disfruta | disfruté
"""

LIKE_GUSTAR = r"""
gustar | me gusta | te gusta | le gusta | me gustó
faltar | me falta | te falta | le falta | me faltó
importar | me importa | te importa | le importa | me importó
doler | me duele | te duele | le duele | me dolió
"""

NOUNS = r"""
casa | la casa | las casas
agua | el agua | las aguas
comida | la comida | las comidas
tiempo | el tiempo | los tiempos
día | el día | los días
noche | la noche | las noches
amor | el amor | los amores
familia | la familia | las familias
amigo | el amigo / la amiga | los amigos / las amigas
trabajo | el trabajo | los trabajos
ciudad | la ciudad | las ciudades
perro | el perro | los perros
boda | la boda | las bodas
prometido | el prometido / la prometida | los prometidos / las prometidas
hambre | el hambre | -
hora | la hora | las horas
semana | la semana | las semanas
dinero | el dinero | -
café | el café | los cafés
hermano | el hermano / la hermana | los hermanos / las hermanas
madre | la madre | las madres
padre | el padre | los padres
hijo | el hijo / la hija | los hijos / las hijas
coche | el coche | los coches
tienda | la tienda | las tiendas
ropa | la ropa | -
cumpleaños | el cumpleaños | los cumpleaños
regalo | el regalo | los regalos
fin de semana | el fin de semana | los fines de semana
vacaciones | - | las vacaciones
cita | la cita | las citas
sueño | el sueño | los sueños
miedo | el miedo | los miedos
ganas | - | las ganas
consejo | el consejo | los consejos
desafío | el desafío | los desafíos
compromiso | el compromiso | los compromisos
vergüenza | la vergüenza | -
éxito | el éxito | los éxitos
"""

ADJECTIVES = r"""
bueno | bueno | buena | buenos / buenas
grande | grande | = | grandes
pequeño | pequeño | pequeña | pequeños / pequeñas
nuevo | nuevo | nueva | nuevos / nuevas
cansado | cansado | cansada | cansados / cansadas
feliz | feliz | = | felices
bonito | bonito | bonita | bonitos / bonitas
rico | rico | rica | ricos / ricas
difícil | difícil | = | difíciles
otro | otro | otra | otros / otras
fácil | fácil | = | fáciles
caro | caro | cara | caros / caras
listo | listo | lista | listos / listas
ocupado | ocupado | ocupada | ocupados / ocupadas
enfermo | enfermo | enferma | enfermos / enfermas
contento | contento | contenta | contentos / contentas
tranquilo | tranquilo | tranquila | tranquilos / tranquilas
equivocado | equivocado | equivocada | equivocados / equivocadas
orgulloso | orgulloso | orgullosa | orgullosos / orgullosas
emocionado | emocionado | emocionada | emocionados / emocionadas
agradecido | agradecido | agradecida | agradecidos / agradecidas
agotado | agotado | agotada | agotados / agotadas
sensible | sensible | = | sensibles
cuánto | cuánto | cuánta | cuántos / cuántas
mucho | mucho | mucha | muchos / muchas
todo | todo | toda | todos / todas
juntos | juntos | juntas | -
"""

# Words that don't fit the tables above.
SPECIAL = {
    "uno, dos, tres": "on its own: uno\nbefore a noun: un perro\nfeminine: una casa",
    "embarazada": "singular: embarazada\nplural: embarazadas",
    "el": "masculine: el\nfeminine: la\nplural: los / las", "la": "masculine: el\nfeminine: la\nplural: los / las", "los": "masculine: el\nfeminine: la\nplural: los / las", "las": "masculine: el\nfeminine: la\nplural: los / las",
    "un": "masculine: un\nfeminine: una\nplural: unos / unas", "una": "masculine: un\nfeminine: una\nplural: unos / unas",
    "mi": "singular: mi\nplural: mis", "tu": "singular: tu\nplural: tus", "su": "singular: su\nplural: sus",
    "él": "he: él\nshe: ella\nthey: ellos / ellas",
    "nosotros": "masculine: nosotros\nfeminine: nosotras",
    "lo": "him / it: lo\nher / it: la\nthem: los / las",
    "le": "one person: le\nmore than one: les", "les": "one person: le\nmore than one: les",
    "hay": "now: hay\nbefore: había\nwill be: habrá",
    "esto": "this: esto\nthat: eso\nthat (far): aquello", "eso": "this: esto\nthat: eso\nthat (far): aquello",
}

# Key forms for a word's *second* meaning (index into otherMeanings), when it's a different part of speech.
MEANING_FORMS = {
    ("mañana", 0): "singular: la mañana\nplural: las mañanas",
    ("tarde", 0): "singular: la tarde\nplural: las tardes",
}


def _rows(block):
    for line in block.strip().splitlines():
        yield [x.strip() for x in line.split("|")]


IRREGULAR_NOSOTROS = {"ir": "vamos", "ser": "somos"}


def nosotros(infinitive: str) -> str:
    """Present-tense 'we' form. Always regular from the infinitive except ir/ser; stem changes
    (quiero, duermo, pido) never happen in the nosotros form."""
    words = infinitive.split(" ")
    verb, rest = words[0], " ".join(words[1:])
    reflexive = verb.endswith("se") and verb[:-2].endswith(("ar", "er", "ir"))
    if reflexive:
        verb = verb[:-2]
    form = IRREGULAR_NOSOTROS.get(verb) or verb[:-2] + {"ar": "amos", "er": "emos", "ir": "imos"}[verb[-2:]]
    return " ".join(x for x in (("nos" if reflexive else ""), form, rest) if x)


def build() -> dict[str, str]:
    """spanish → 'label: value' lines, the same format the dictionary importer produces."""
    forms: dict[str, str] = {}
    for word, yo, tu, el, past in _rows(VERBS):
        forms[word] = f"yo: {yo}\ntú: {tu}\nél / ella: {el}\nnosotros: {nosotros(word)}\npast (yo): {past}"
    for word, a, b, c, past in _rows(LIKE_GUSTAR):
        we = "nos " + c.split(" ", 1)[1]
        forms[word] = f"a mí: {a}\na ti: {b}\na él / ella: {c}\na nosotros: {we}\npast: {past}"
    for word, sing, plural in _rows(NOUNS):
        lines = []
        if sing != "-": lines.append(f"singular: {sing}")
        if plural != "-": lines.append(f"plural: {plural}")
        forms[word] = "\n".join(lines)
    for word, m, f, pl in _rows(ADJECTIVES):
        lines = [f"m. & f.: {m}"] if f == "=" else [f"masculine: {m}", f"feminine: {f}"]
        if pl != "-":
            lines.append(f"plural: {pl}")
        forms[word] = "\n".join(lines)
    forms.update(SPECIAL)
    return forms


FORMS = build()


# When an example sentence uses a form that isn't in the table, explain it in plain English for a
# beginner. spanish → (the word as written in the sentence, note). Markdown: **bold**, *italic*.
# The form is also added to Key forms as "in the example".
EXAMPLE_NOTES = {
    "dormir": ("Dormiste", "**dormiste** = *dormir* in the **past** tense for **you** (tú): \"did you sleep?\""),
    "aprender": ("aprendiendo", "**aprendiendo** is the **-ing** form of *aprender*. *Estoy aprendiendo* = I am learning."),
    "ahorrar": ("ahorrando", "**ahorrando** is the **-ing** form of *ahorrar*. *Estamos ahorrando* = we are saving."),
    "dar": ("Dame", "**dame** = *da* (a **command** to **you**: give!) + *me* (to me)."),
    "escribir": ("Escríbeme", "**escríbeme** = *escribe* (a **command** to **you**: write!) + *me* (to me). The accent keeps the stress on *crí*."),
    "dejar": ("Déjame", "**déjame** = *deja* (a **command** to **you**: let!) + *me* (me). The accent keeps the stress on *dé*."),
    "poner": ("Pon", "**pon** is a **command** to **you** (tú): put! It's irregular — just *pon*."),
    "terminar": ("terminaste", "**terminaste** = *terminar* in the **past** tense for **you** (tú): \"did you finish?\""),
    "decir": ("dijiste", "**dijiste** = *decir* in the **past** tense for **you** (tú): \"what did you say?\" (irregular)"),
    "ganar": ("ganó", "**ganó** = *ganar* in the **past** tense for **he / she**: \"who won?\""),
    "olvidar": ("olvidaron", "**olvidaron** = *olvidar* in the **past** tense for **they**. *Se me olvidaron las llaves* is literally \"the keys got forgotten on me\" — a blame-free way to say *I forgot my keys*."),
    "jugar": ("juegan", "**juegan** = *jugar* in the **present** tense for **they** (ellos / ellas)."),
    "casarse": ("se casan", "**se casan** = *casarse* in the **present** tense for **you two / they** (ustedes / ellos). Spanish often uses the present for planned future events."),
    "enojarse": ("enojes", "**no te enojes** = \"don't get angry\" — a **don't-do-it command** to **you** (tú). Commands with *no* use this special form."),
    "fingir": ("finjas", "**no finjas** = \"don't pretend\" — a **don't-do-it command** to **you** (tú). Commands with *no* use this special form."),
    "mirar": ("Mira", "**¡Mira!** here is a **command** to **you** (tú): \"Look!\" It looks the same as the *él / ella* form — tú commands usually do."),
    "escuchar": ("Escucha", "**¡Escucha!** here is a **command** to **you** (tú): \"Listen!\" Same spelling as the *él / ella* form."),
    "probar": ("Prueba", "**¡Prueba!** here is a **command** to **you** (tú): \"Try it!\" Same spelling as the *él / ella* form."),
    "seguir": ("Sigue", "**sigue** here is a **command** to **you** (tú): \"keep going\". Same spelling as the *él / ella* form."),
    "aguantar": ("Aguanta", "**¡Aguanta!** here is a **command** to **you** (tú): \"Hang on!\" Same spelling as the *él / ella* form."),
    "disfrutar": ("Disfruta", "**¡Disfruta!** here is a **command** to **you** (tú): \"Enjoy!\" Same spelling as the *él / ella* form."),
}
