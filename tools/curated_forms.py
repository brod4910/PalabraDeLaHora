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
mañana | la mañana | las mañanas
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
"""


def _rows(block):
    for line in block.strip().splitlines():
        yield [x.strip() for x in line.split("|")]


def build() -> dict[str, str]:
    """spanish → 'label: value' lines, the same format the dictionary importer produces."""
    forms: dict[str, str] = {}
    for word, yo, tu, el, past in _rows(VERBS):
        forms[word] = f"yo: {yo}\ntú: {tu}\nél / ella: {el}\npast (yo): {past}"
    for word, a, b, c, past in _rows(LIKE_GUSTAR):
        forms[word] = f"a mí: {a}\na ti: {b}\na él / ella: {c}\npast: {past}"
    for word, sing, plural in _rows(NOUNS):
        lines = []
        if sing != "-": lines.append(f"singular: {sing}")
        if plural != "-": lines.append(f"plural: {plural}")
        forms[word] = "\n".join(lines)
    for word, m, f, pl in _rows(ADJECTIVES):
        forms[word] = f"m. & f.: {m}\nplural: {pl}" if f == "=" else f"masculine: {m}\nfeminine: {f}\nplural: {pl}"
    return forms


FORMS = build()
