# Additional deck entries, grouped by level.
# Format (one per line):
#   spanish | english | part of speech | phonetic | example | example translation | pattern | tip (optional)
# Part of speech "phrase" / "greeting" / "expression" / "idiom" makes it an everyday phrase card.
# Levels follow CEFR roughly: novice ≈ A1, beginner ≈ A2, intermediate ≈ B1, fluent ≈ B2–C1.

NEW = r"""
## novice
#! Core little words (closed class). Wiktionary describes these instead of translating them
#! ("Used to express…", "plural masculine or neuter pronoun"), so the importer can't build good
#! cards for them — and they're the first words a beginner needs.
y | and | conjunction | ee | Quiero tacos y agua. | I want tacos and water. | this + y + that | Before a word starting with an i sound it becomes e: padres e hijos.
o | or | conjunction | oh | ¿Café o té? | Coffee or tea? | this + o + that | Before a word starting with an o sound it becomes u: siete u ocho.
a | to / at | preposition | ah | Vamos a la playa. | Let's go to the beach. | ir a + place  ·  a las + hour = at … o'clock | Also before a person after many verbs, with no English word: Llamo a mi mamá.
de | of / from | preposition | deh | Soy de México. | I'm from Mexico. | ser de + place  ·  la casa de Ana = Ana's house | Spanish has no 's: Ana's house = la casa de Ana.
en | in / on / at | preposition | ehn | Estoy en casa. | I'm at home. | estar en + place | One word for in, on and at: en la mesa = on the table.
con | with | preposition | kohn | Voy con mi hermana. | I'm going with my sister. | con + person / thing | With me = conmigo, with you = contigo.
por | for / because of | preposition | pohr | Gracias por todo. | Thanks for everything. | Gracias por + noun  ·  por la mañana = in the morning | ¿Por qué? = why?  ·  porque = because.
para | for / in order to | preposition | PAH-rah | Esto es para ti. | This is for you. | para + person  ·  para + infinitive = in order to | para = for a person or a purpose; por = because of.
sin | without | preposition | seen | Un café sin azúcar, por favor. | A coffee without sugar, please. | sin + noun
el | the | article | ehl | El perro está en la casa. | The dog is in the house. | el + masculine noun | Él with an accent means he.
la | the | article | lah | La comida está lista. | The food is ready. | la + feminine noun | Before a verb it means her / it: La veo = I see her.
los | the | article | lohs | Los niños están en la escuela. | The kids are at school. | los + masculine or mixed plural noun | Before a verb it means them: Los veo = I see them.
las | the | article | lahs | Las tortillas están calientes. | The tortillas are hot. | las + feminine plural noun | Before a verb it means them: Las compro = I buy them.
un | a / an | article | oon | Tengo un perro. | I have a dog. | un + masculine noun | On its own, one is uno: ¿Cuántos? — Uno.
una | a / an / one | article | OO-nah | Tengo una pregunta. | I have a question. | una + feminine noun | Also the number one: una hora = one hour.
al | to the | contraction | ahl | Vamos al parque. | Let's go to the park. | a + el = al | Only with el: a la casa stays two words.
del | of the / from the | contraction | dehl | Vengo del trabajo. | I'm coming from work. | de + el = del | Only with el: de la casa stays two words.
que | that | conjunction | keh | Creo que sí. | I think so. | creo que + sentence = I think that … | Without an accent it joins ideas; with one, qué means what.
qué | what | pronoun | keh | ¿Qué quieres comer? | What do you want to eat? | ¿Qué + verb? | ¡Qué bonito! = How pretty!
me | me / myself | pronoun | meh | ¿Me ayudas? | Will you help me? | me + verb | It goes before the verb: Me gusta = I like it.
te | you / yourself | pronoun | teh | Te extraño. | I miss you. | te + verb | With an accent, té means tea.
se | himself / herself / themselves | pronoun | seh | Se llama Sofía. | Her name is Sofía. | se + verb | Many verbs come with se: se llama, se fue (he left).
lo | it / him | pronoun | loh | No lo sé. | I don't know. | lo + verb | Lo que = what: Lo que quieras = whatever you want.
le | to him / to her / to you (usted) | pronoun | leh | Le doy un regalo. | I'm giving him a gift. | le + verb | The rest of the sentence tells you who: Le escribo a mi mamá.
les | to them / to you all | pronoun | lehs | ¿Les gusta la comida? | Do you all like the food? | les + verb | Les gusta = they like it, or you all like it.
nos | us / ourselves | pronoun | nohs | Nos vemos mañana. | See you tomorrow. | nos + verb | Nos vemos is literally we see each other.
mi | my | determiner | mee | Mi casa es tu casa. | My house is your house. | mi + noun | With an accent, mí means me: para mí = for me.
tu | your | determiner | too | ¿Cómo está tu mamá? | How's your mom? | tu + noun | With an accent, tú means you: ¿Y tú?
su | his / her / their / your (usted) | determiner | soo | Su casa es muy bonita. | Her house is very pretty. | su + noun | One word for his, her and their: the context tells you which.
yo | I | pronoun | yoh | Yo cocino hoy. | I'm cooking today. | yo + verb | Often left out: Cocino hoy means the same.
tú | you | pronoun | too | ¿Y tú? | And you? | tú + verb | The casual you, for friends and family. With strangers: usted.
él | he / him | pronoun | ehl | Él es mi hermano. | He's my brother. | él + verb | Without an accent, el means the.
nosotros | we / us | pronoun | noh-SOH-trohs | Nosotros vamos mañana. | We're going tomorrow. | nosotros + verb | A group of only women says nosotras.
usted | you (formal) | pronoun | oos-TEHD | ¿Cómo está usted? | How are you? | usted + él / ella verb form | For older people and strangers.
ustedes | you all | pronoun | oos-TEH-dehs | ¿Ustedes quieren café? | Do you all want coffee? | ustedes + ellos verb form | In Mexico this is the only plural you; vosotros is used in Spain.
muy | very | adverb | mooy | Estoy muy cansada. | I'm very tired. | muy + adjective | With a noun, use mucho: mucho trabajo = a lot of work.
ni | not even / nor | conjunction | nee | No tengo ni idea. | I have no idea. | ni … ni … = neither … nor … | Ni modo = oh well (very Mexican).
hay | there is / there are | verb | eye | ¿Hay café? | Is there coffee? | Hay + noun  ·  ¿Hay …? = Is there …? | Same word for one or many: hay un perro, hay dos perros.
esto | this | pronoun | EHS-toh | ¿Cuánto cuesta esto? | How much is this? | esto on its own, no noun after it | With a noun, use este / esta: este libro.
eso | that | pronoun | EH-soh | ¿Qué es eso? | What's that? | eso on its own, no noun after it | ¡Eso! = That's it! Exactly!
sí | yes | adverb | see | Sí, claro. | Yes, of course. | Sí + claro / Sí, por favor | With an accent it means yes; si without one means if.
no | no / not | adverb | noh | No hablo mucho español. | I don't speak much Spanish. | No goes right before the verb
bien | well / fine | adverb | byehn | Estoy bien, gracias. | I'm fine, thanks. | Estoy bien  ·  Muy bien = very well
mal | bad / badly | adverb | mahl | Me siento mal hoy. | I feel bad today. | Me siento + bien / mal
bueno | good | adjective | BWEH-noh | La película es muy buena. | The movie is very good. | muy + adjective | Before a masculine noun it shortens to buen: buen día.
grande | big | adjective | GRAHN-deh | Tenemos una casa grande. | We have a big house. | noun + grande | Before a noun it becomes gran = great: un gran día.
pequeño | small | adjective | peh-KEH-nyoh | El perro es pequeño. | The dog is small. | ser + pequeño / pequeña
nuevo | new | adjective | NWEH-boh | Tengo un teléfono nuevo. | I have a new phone. | noun + nuevo / nueva
hoy | today | adverb | oy | Hoy trabajo hasta las cinco. | Today I work until five. | hasta las + hour = until … o'clock
ayer | yesterday | adverb | ah-YEHR | Ayer comimos tacos. | Yesterday we ate tacos. | Ayer + past tense
aquí | here | adverb | ah-KEE | Estoy aquí. | I'm here. | Estoy aquí  ·  Ven aquí = Come here
mucho | a lot / much | adverb | MOO-choh | Te quiero mucho. | I love you a lot. | verb + mucho  ·  mucho / mucha + noun
más | more | adverb | mahs | Quiero más café. | I want more coffee. | más + noun  ·  más + adjective + que = more … than
uno, dos, tres | one, two, three | numbers | OO-noh, dohs, trehs | Tengo tres hermanas. | I have three sisters. | number + plural noun | Uno becomes un before a masculine noun: un perro.
hora | hour / time | noun (f.) | OH-rah | ¿Qué hora es? | What time is it? | Son las + number = It's … o'clock | It's one o'clock = Es la una.
semana | week | noun (f.) | seh-MAH-nah | Nos vemos la próxima semana. | See you next week. | la próxima semana = next week
dinero | money | noun (m.) | dee-NEH-roh | No tengo dinero en efectivo. | I don't have cash. | No tengo + noun
café | coffee | noun (m.) | kah-FEH | Un café con leche, por favor. | A coffee with milk, please. | Un + drink + por favor
hermano | brother / sibling | noun | ehr-MAH-noh | Mi hermano vive en Texas. | My brother lives in Texas. | Mi + family member + vive en + place | hermana = sister, hermanos = siblings
madre | mother | noun (f.) | MAH-dreh | Mi madre cocina muy bien. | My mother cooks very well. | Mi madre + verb | Everyday word: mamá.
padre | father | noun (m.) | PAH-dreh | Mi padre trabaja mucho. | My father works a lot. | padres = parents | In Mexico, ¡qué padre! means how cool!
hijo | son / child | noun | EE-hoh | Queremos tener hijos. | We want to have kids. | hijos = children, hija = daughter
coche | car | noun (m.) | KOH-cheh | El coche está en la calle. | The car is on the street. | estar en + place | In Mexico and much of Latin America: carro.
vivir | to live | verb | bee-BEER | Vivimos en una casa pequeña. | We live in a small house. | Vivir en + place
ver | to see / to watch | verb | behr | ¿Vemos una película? | Shall we watch a movie? | ¿Vemos …? = Shall we watch …?
dar | to give | verb | dahr | Dame un beso. | Give me a kiss. | Dame + noun = Give me …
decir | to say / to tell | verb | deh-SEER | ¿Qué dijiste? | What did you say? | Dime = Tell me | Irregular: digo, dices, dice.
venir | to come | verb | beh-NEER | ¿Vienes a cenar? | Are you coming to dinner? | Venir a + infinitive
llamar | to call | verb | yah-MAHR | Te llamo más tarde. | I'll call you later. | Me llamo + name = My name is …
leer | to read | verb | leh-EHR | Me gusta leer en la cama. | I like to read in bed. | Me gusta + infinitive
escribir | to write | verb | ehs-kree-BEER | Escríbeme cuando llegues. | Text me when you get there. | Escríbeme = Write to me / text me
comprar | to buy | verb | kohm-PRAHR | Tenemos que comprar leche. | We have to buy milk. | Tenemos que + infinitive = We have to …
pagar | to pay | verb | pah-GAHR | Yo pago la cena. | I'll pay for dinner. | Pagar + thing (no word for 'for')
ayudar | to help | verb | ah-yoo-DAHR | ¿Me ayudas con esto? | Can you help me with this? | ¿Me ayudas con + noun?
tomar | to take / to drink | verb | toh-MAHR | ¿Tomamos un café? | Shall we get a coffee? | ¿Tomamos + drink?
jugar | to play (games, sports) | verb | hoo-GAHR | Los niños juegan en el parque. | The kids play in the park. | Jugar a + game | u → ue: juego, juegas.
buenos días | good morning | greeting | BWEH-nohs DEE-ahs | Buenos días, ¿cómo dormiste? | Good morning, how did you sleep? | Buenos días · Buenas tardes · Buenas noches
¿cómo estás? | how are you? | phrase | KOH-moh ehs-TAHS | Hola, amor, ¿cómo estás? | Hi, love, how are you? | ¿Cómo estás? (casual)  ·  ¿Cómo está? (formal) | Answer: Bien, ¿y tú?
¿qué tal? | how's it going? | phrase | keh TAHL | ¿Qué tal tu día? | How was your day? | ¿Qué tal + noun? = How is / was …?
mucho gusto | nice to meet you | phrase | MOO-choh GOOS-toh | Me llamo Ana, mucho gusto. | My name is Ana, nice to meet you. | Mucho gusto  ·  Encantado / Encantada
me llamo | my name is | phrase | meh YAH-moh | Me llamo Sara, ¿y tú? | My name is Sara, and you? | ¿Cómo te llamas? = What's your name?
de nada | you're welcome | phrase | deh NAH-dah | —Gracias. —De nada. | "Thanks." "You're welcome." | Gracias → De nada
perdón | excuse me / sorry | phrase | pehr-DOHN | Perdón, ¿dónde está el baño? | Excuse me, where's the bathroom? | Perdón + question
no entiendo | I don't understand | phrase | noh ehn-TYEHN-doh | Perdón, no entiendo. ¿Puedes repetir? | Sorry, I don't understand. Can you repeat? | ¿Puedes repetir? = Can you repeat?
más despacio, por favor | slower, please | phrase | mahs dehs-PAH-syoh, pohr fah-BOHR | Más despacio, por favor. Estoy aprendiendo. | Slower, please. I'm learning. | Más despacio, por favor
te quiero | I love you | phrase | teh KYEH-roh | Te quiero mucho, mi amor. | I love you so much, my love. | Te quiero (everyday)  ·  Te amo (deeper, more intense)
hasta luego | see you later | phrase | AHS-tah LWEH-goh | Hasta luego, que te vaya bien. | See you later, take care. | Hasta luego · Hasta mañana · Hasta pronto
nos vemos | see you | phrase | nohs BEH-mohs | Nos vemos a las siete. | See you at seven. | Nos vemos + time / place
claro | of course / sure | phrase | KLAH-roh | —¿Me ayudas? —¡Claro! | "Will you help me?" "Sure!" | ¡Claro! · Claro que sí = Of course
está bien | okay / that's fine | phrase | ehs-TAH byehn | Está bien, vamos. | Okay, let's go. | Está bien | Spain says vale; Mexico says sale or órale.
¿qué es esto? | what is this? | phrase | keh ehs EHS-toh | ¿Qué es esto? Huele delicioso. | What is this? It smells delicious. | ¿Qué es + esto / eso?
la cuenta, por favor | the check, please | phrase | lah KWEHN-tah, pohr fah-BOHR | Disculpe, la cuenta, por favor. | Excuse me, the check, please. | Disculpe = excuse me (to a stranger)
salud | health | noun (f.) | sah-LOOD | La salud es lo más importante. | Health is the most important thing. | la salud  ·  ¡Salud! = Cheers! / Bless you! | Said with a toast and when someone sneezes.
buen provecho | enjoy your meal | phrase | bwehn proh-BEH-choh | ¡Buen provecho! | Enjoy your meal! | ¡Buen provecho! | Said to people who are eating — even strangers.

## beginner
preguntar | to ask (a question) | verb | preh-goon-TAHR | Te quiero preguntar algo. | I want to ask you something. | Preguntar + algo / por + person | Asking FOR something is pedir.
pedir | to ask for / to order | verb | peh-DEER | Vamos a pedir una pizza. | We're going to order a pizza. | Pedir + thing (no word for 'for') | e → i: pido, pides.
contestar | to answer | verb | kohn-tehs-TAHR | No contesta el teléfono. | He's not answering the phone. | Contestar + thing
empezar | to start | verb | ehm-peh-SAHR | La película empieza a las ocho. | The movie starts at eight. | Empezar a + infinitive | e → ie: empiezo.
terminar | to finish | verb | tehr-mee-NAHR | ¿Ya terminaste? | Are you done already? | Terminar de + infinitive = finish doing …
volver | to come back | verb | bohl-BEHR | Vuelvo en diez minutos. | I'll be back in ten minutes. | Volver a + infinitive = to do … again | o → ue: vuelvo.
cambiar | to change | verb | kahm-BYAHR | Quiero cambiar de trabajo. | I want to change jobs. | Cambiar de + noun = switch …
olvidar | to forget | verb | ohl-bee-DAHR | Se me olvidaron las llaves. | I forgot my keys. | Se me olvidó + thing (it 'got forgotten' on me) | Very natural, blame-free way to say it.
perder | to lose / to miss | verb | pehr-DEHR | Perdí el autobús. | I missed the bus. | Perder + thing | e → ie: pierdo.
ganar | to win / to earn | verb | gah-NAHR | ¿Quién ganó el partido? | Who won the game? | Ganar + game / dinero
mirar | to look at | verb | mee-RAHR | ¡Mira esto! | Look at this! | Mira + thing (no word for 'at')
escuchar | to listen to | verb | ehs-koo-CHAHR | Escucha esta canción. | Listen to this song. | Escuchar + thing (no word for 'to')
caminar | to walk | verb | kah-mee-NAHR | ¿Caminamos un rato? | Shall we walk for a bit? | un rato = a while
descansar | to rest | verb | dehs-kahn-SAHR | Necesitas descansar. | You need to rest. | Necesitas + infinitive
limpiar | to clean | verb | leem-PYAHR | Hoy limpiamos la casa. | Today we're cleaning the house. | Limpiar + thing
llevar | to take / to carry / to wear | verb | yeh-BAHR | ¿Llevo algo a la fiesta? | Should I bring something to the party? | ¿Llevo + thing? = Should I take …? | llevar = take there; traer = bring here.
traer | to bring | verb | trah-EHR | ¿Me traes un vaso de agua? | Can you bring me a glass of water? | ¿Me traes + thing? | First person: traigo.
poner | to put | verb | poh-NEHR | Pon la mesa, por favor. | Set the table, please. | poner la mesa = set the table | First person: pongo.
creer | to believe / to think | verb | kreh-EHR | Creo que sí. | I think so. | Creo que + sentence  ·  Creo que no = I don't think so
parecer | to seem | verb | pah-reh-SEHR | ¿Qué te parece? | What do you think? | Me parece + adjective = It seems … to me
otro | other / another | adjective | OH-troh | ¿Quieres otro café? | Do you want another coffee? | otro + noun (never 'un otro')
todo | all / everything | pronoun | TOH-doh | Todo está bien. | Everything is fine. | todo el día = all day
cada | each / every | adjective | KAH-dah | Te llamo cada noche. | I call you every night. | cada + singular noun
algo | something | pronoun | AHL-goh | ¿Quieres algo de tomar? | Do you want something to drink? | algo de + infinitive
nada | nothing | pronoun | NAH-dah | No pasa nada. | No worries. / It's nothing. | No + verb + nada (double negative is correct)
alguien | someone | pronoun | AHL-gyehn | Alguien está en la puerta. | Someone is at the door. | Alguien + verb
nadie | nobody | pronoun | NAH-dyeh | No hay nadie en casa. | Nobody's home. | No + verb + nadie
temprano | early | adverb | tehm-PRAH-noh | Mañana me levanto temprano. | Tomorrow I'm getting up early. | levantarse temprano = get up early
tarde | late / afternoon | adverb | TAHR-deh | Llego tarde, lo siento. | I'm running late, sorry. | tarde = late  ·  la tarde = the afternoon
todavía | still / yet | adverb | toh-dah-BEE-ah | Todavía no he comido. | I haven't eaten yet. | todavía no = not yet
ya | already / now | adverb | yah | Ya llegué. | I'm here. (I've arrived.) | ya no = not anymore
después | after / later | adverb | dehs-PWEHS | Después de cenar, vemos una película. | After dinner, we'll watch a movie. | después de + infinitive
antes | before | adverb | AHN-tehs | Lávate las manos antes de comer. | Wash your hands before eating. | antes de + infinitive
cerca | near / close | adverb | SEHR-kah | ¿Está lejos? —No, está muy cerca. | "Is it far?" "No, it's really close." | cerca de + place  ·  lejos de = far from
tienda | store | noun (f.) | TYEHN-dah | Voy a la tienda, ¿necesitas algo? | I'm going to the store, need anything? | Voy a + place
ropa | clothes | noun (f.) | RROH-pah | Tengo que lavar la ropa. | I have to do the laundry. | lavar la ropa = do laundry | Ropa is singular in Spanish: la ropa está limpia.
cumpleaños | birthday | noun (m.) | koom-pleh-AH-nyohs | ¿Cuándo es tu cumpleaños? | When is your birthday? | ¿Cuándo es + event?
regalo | gift | noun (m.) | rreh-GAH-loh | Te compré un regalo. | I bought you a gift. | Te compré + noun = I bought you …
fin de semana | weekend | noun (m.) | feen deh seh-MAH-nah | ¿Qué hacemos este fin de semana? | What are we doing this weekend? | este fin de semana = this weekend
vacaciones | vacation | noun (f. pl.) | bah-kah-SYOH-nehs | Nos vamos de vacaciones en julio. | We're going on vacation in July. | irse de vacaciones = go on vacation
fácil | easy | adjective | FAH-seel | Es más fácil de lo que pensaba. | It's easier than I thought. | más fácil de lo que = easier than
caro | expensive | adjective | KAH-roh | Es muy caro. ¿Hay algo más barato? | It's really expensive. Is there anything cheaper? | caro ↔ barato (cheap)
listo | ready / smart | adjective | LEES-toh | ¿Estás lista? | Are you ready? | estar listo = be ready  ·  ser listo = be smart
ocupado | busy | adjective | oh-koo-PAH-doh | Estoy ocupado ahora, te llamo luego. | I'm busy right now, I'll call you later. | Estoy ocupado / ocupada
enfermo | sick | adjective | ehn-FEHR-moh | Estoy enfermo, me quedo en casa. | I'm sick, I'm staying home. | Estoy enfermo / enferma
contento | happy / pleased | adjective | kohn-TEHN-toh | Estoy muy contenta contigo. | I'm really happy with you. | estar contento con + person
tranquilo | calm / relaxed | adjective | trahn-KEE-loh | Tranquila, todo va a estar bien. | Relax, everything will be okay. | Tranquilo / Tranquila = Relax, don't worry
juntos | together | adverb | HOON-tohs | Me encanta cocinar juntos. | I love cooking together. | verb + juntos
me gustaría | I would like | phrase | meh goos-tah-REE-ah | Me gustaría un vaso de agua. | I'd like a glass of water. | Me gustaría + noun / infinitive (polite)
¿qué pasa? | what's going on? | phrase | keh PAH-sah | ¿Qué pasa? Te veo triste. | What's wrong? You look sad. | ¿Qué pasa? · No pasa nada = It's nothing
no te preocupes | don't worry | phrase | noh teh preh-oh-KOO-pehs | No te preocupes, yo lo hago. | Don't worry, I'll do it. | No te + subjunctive = Don't …
tengo que irme | I have to go | phrase | TEHN-goh keh EER-meh | Tengo que irme, nos vemos mañana. | I have to go, see you tomorrow. | Tengo que + infinitive
¿cómo se dice…? | how do you say…? | phrase | KOH-moh seh DEE-seh | ¿Cómo se dice "spoon" en español? | How do you say "spoon" in Spanish? | ¿Cómo se dice + word + en español? | (It's cuchara.)
¿qué significa…? | what does … mean? | phrase | keh seeg-nee-FEE-kah | ¿Qué significa "ahorita"? | What does "ahorita" mean? | ¿Qué significa + word?
estoy de acuerdo | I agree | phrase | ehs-TOY deh ah-KWEHR-doh | Estoy de acuerdo contigo. | I agree with you. | Estar de acuerdo con + person
qué bueno | that's great | phrase | keh BWEH-noh | ¡Qué bueno que viniste! | I'm so glad you came! | ¡Qué bueno que + verb!
a veces | sometimes | phrase | ah BEH-sehs | A veces cocino yo, a veces cocinas tú. | Sometimes I cook, sometimes you cook. | A veces + verb
por supuesto | of course | phrase | pohr soo-PWEHS-toh | —¿Vienes? —¡Por supuesto! | "Are you coming?" "Of course!" | ¡Por supuesto!
ten cuidado | be careful | phrase | tehn kwee-DAH-doh | Ten cuidado, está caliente. | Careful, it's hot. | Ten cuidado con + noun
que te vaya bien | hope it goes well / take care | phrase | keh teh BAH-yah byehn | ¡Que te vaya bien en el trabajo! | Have a good day at work! | Que + subjunctive = I hope …
lo mismo | the same | phrase | loh MEES-moh | Para mí, lo mismo. | Same for me. | Para mí, + order
ya voy | coming! / on my way | phrase | yah boy | ¡Ya voy, ya voy! | Coming, coming! | Ya voy · Ya vengo = I'll be right back
cuídate | take care | phrase | KWEE-dah-teh | Cuídate mucho. Te quiero. | Take good care of yourself. I love you. | Cuídate · Cuídense (to a group)
¿estás bien? | are you okay? | phrase | ehs-TAHS byehn | ¿Estás bien? Pareces cansada. | Are you okay? You look tired. | ¿Estás + adjective?

## intermediate
lograr | to achieve / to manage to | verb | loh-GRAHR | Por fin logré terminarlo. | I finally managed to finish it. | Lograr + infinitive = manage to …
intentar | to try | verb | een-tehn-TAHR | Voy a intentar hablar solo en español. | I'm going to try to speak only Spanish. | Intentar + infinitive
darse cuenta | to realize | verb | DAHR-seh KWEHN-tah | Me di cuenta de que era tarde. | I realized it was late. | Darse cuenta de que + sentence | Realizar means to carry out, not to realize.
acordarse | to remember | verb | ah-kohr-DAHR-seh | ¿Te acuerdas de mi tía? | Do you remember my aunt? | Acordarse de + person / thing | o → ue: me acuerdo.
quedarse | to stay | verb | keh-DAHR-seh | Me quedo en casa esta noche. | I'm staying home tonight. | Quedarse en + place
preocuparse | to worry | verb | preh-oh-koo-PAHR-seh | Me preocupo por ti. | I worry about you. | Preocuparse por + person / thing
enojarse | to get angry | verb | eh-noh-HAHR-seh | No te enojes, era una broma. | Don't get mad, it was a joke. | Enojarse con + person | In Spain: enfadarse.
casarse | to get married | verb | kah-SAHR-seh | ¿Cuándo se casan? | When are you two getting married? | Casarse con + person
mudarse | to move (house) | verb | moo-DAHR-seh | Nos mudamos a un apartamento nuevo. | We're moving to a new apartment. | Mudarse a + place
ahorrar | to save (money) | verb | ah-oh-RRAHR | Estamos ahorrando para la boda. | We're saving for the wedding. | Ahorrar para + noun
gastar | to spend | verb | gahs-TAHR | Gastamos demasiado en comida. | We spend too much on food. | Gastar en + noun
compartir | to share | verb | kohm-pahr-TEER | ¿Compartimos un postre? | Shall we share a dessert? | ¿Compartimos + noun?
cuidar | to take care of | verb | kwee-DAHR | Yo cuido al perro este fin de semana. | I'm taking care of the dog this weekend. | Cuidar a + person / pet
elegir | to choose | verb | eh-leh-HEER | Tú eliges el restaurante. | You choose the restaurant. | Elegir + noun | e → i, g → j: elijo.
probar | to try / to taste | verb | proh-BAHR | Prueba esto, está buenísimo. | Try this, it's amazing. | Probar = taste or try on  ·  intentar = attempt | o → ue: pruebo.
merecer | to deserve | verb | meh-reh-SEHR | Te mereces un descanso. | You deserve a break. | Merecerse + noun
apoyar | to support | verb | ah-poh-YAHR | Siempre te voy a apoyar. | I'll always support you. | Apoyar a + person | Soportar means to put up with — a false friend.
dejar | to leave / to let | verb | deh-HAHR | Déjame pensarlo. | Let me think about it. | Dejar de + infinitive = to stop doing …
seguir | to keep going / to follow | verb | seh-GEER | Sigue derecho dos cuadras. | Keep going straight two blocks. | Seguir + -ando / -iendo = keep …-ing | e → i: sigo.
faltar | to be missing / to need | verb | fahl-TAHR | Me falta un poco de práctica. | I need a bit more practice. | Me falta + noun (works like gustar)
importar | to matter | verb | eem-pohr-TAHR | No me importa. | I don't mind. / It doesn't matter to me. | Me importa + noun (works like gustar)
doler | to hurt | verb | doh-LEHR | Me duele la cabeza. | I have a headache. | Me duele + body part (works like gustar)
molestar | to bother | verb | moh-lehs-TAHR | ¿Te molesta si abro la ventana? | Do you mind if I open the window? | ¿Te molesta si + verb?
aunque | although / even if | conjunction | OWN-keh | Aunque estoy cansada, voy a ir. | Even though I'm tired, I'm going. | Aunque + indicative (fact) / subjunctive (hypothetical)
sin embargo | however | conjunction | seen ehm-BAHR-goh | Es caro; sin embargo, vale la pena. | It's expensive; however, it's worth it. | sentence; sin embargo, sentence
por eso | that's why | conjunction | pohr EH-soh | Llovía, por eso no salimos. | It was raining, that's why we didn't go out. | cause, por eso + result
entonces | so / then | adverb | ehn-TOHN-sehs | Entonces, ¿qué hacemos? | So, what do we do? | Entonces, + question
además | besides / also | adverb | ah-deh-MAHS | Además, es muy barato. | Besides, it's really cheap. | Además, + sentence
mientras | while | conjunction | MYEHN-trahs | Escucho podcasts mientras cocino. | I listen to podcasts while I cook. | mientras + verb
casi | almost | adverb | KAH-see | Casi llegamos. | We're almost there. | casi + verb / adjective
quizás | maybe | adverb | kee-SAHS | Quizás vamos mañana. | Maybe we'll go tomorrow. | Quizás + indicative / subjunctive (more doubt)
cita | date / appointment | noun (f.) | SEE-tah | Tengo cita con el doctor. | I have a doctor's appointment. | tener cita con + person | The same word means a romantic date.
sueño | dream / sleepiness | noun (m.) | SWEH-nyoh | Tengo sueño. | I'm sleepy. | tener sueño = be sleepy  ·  un sueño = a dream
miedo | fear | noun (m.) | MYEH-doh | Tengo miedo de las arañas. | I'm scared of spiders. | tener miedo de + noun
ganas | urge / desire | noun (f. pl.) | GAH-nahs | Tengo ganas de verte. | I can't wait to see you. | Tener ganas de + infinitive = feel like …
consejo | advice | noun (m.) | kohn-SEH-hoh | ¿Me das un consejo? | Can you give me some advice? | dar un consejo = give advice
equivocado | wrong / mistaken | adjective | eh-kee-boh-KAH-doh | Creo que estás equivocado. | I think you're wrong. | estar equivocado = be wrong
orgulloso | proud | adjective | ohr-goo-YOH-soh | Estoy muy orgulloso de ti. | I'm very proud of you. | Estar orgulloso de + person
emocionado | excited | adjective | eh-moh-syoh-NAH-doh | Estoy emocionada por la boda. | I'm excited about the wedding. | Estar emocionado por + noun
agradecido | grateful | adjective | ah-grah-deh-SEE-doh | Estoy agradecida por todo. | I'm grateful for everything. | Estar agradecido por + noun
vale la pena | it's worth it | phrase | BAH-leh lah PEH-nah | El viaje vale la pena. | The trip is worth it. | Vale la pena + infinitive
tener razón | to be right | phrase | teh-NEHR rrah-SOHN | Tienes razón. | You're right. | Tener razón · No tener razón
hace falta | it's needed | phrase | AH-seh FAHL-tah | Hace falta más sal. | It needs more salt. | Hace falta + noun / infinitive
me da igual | I don't mind / either way | phrase | meh dah ee-GWAHL | —¿Pizza o tacos? —Me da igual. | "Pizza or tacos?" "I don't mind." | Me da igual · Me da lo mismo
acabar de | to have just (done) | phrase | ah-kah-BAHR deh | Acabo de llegar. | I just got here. | Acabar de + infinitive = to have just …
estar a punto de | to be about to | phrase | ehs-TAHR ah POON-toh deh | Estoy a punto de salir. | I'm about to leave. | Estar a punto de + infinitive
¿qué te parece si…? | how about if…? | phrase | keh teh pah-REH-seh see | ¿Qué te parece si cenamos fuera? | How about we eat out? | ¿Qué te parece si + verb?
me encantaría | I'd love to | phrase | meh ehn-kahn-tah-REE-ah | ¡Me encantaría ir contigo! | I'd love to go with you! | Me encantaría + infinitive
a lo mejor | maybe | phrase | ah loh meh-HOHR | A lo mejor llueve mañana. | Maybe it'll rain tomorrow. | A lo mejor + indicative | Extremely common in everyday speech.
ojalá | I hope / hopefully | phrase | oh-hah-LAH | Ojalá que haga sol el sábado. | I hope it's sunny on Saturday. | Ojalá (que) + subjunctive
en serio | seriously / really? | phrase | ehn SEH-ryoh | ¿En serio? ¡No lo puedo creer! | Seriously? I can't believe it! | ¿En serio?
me cae bien | I like him / her (as a person) | phrase | meh KAH-eh byehn | Tu hermano me cae muy bien. | I really like your brother. | Me cae bien / mal + person | For people, this sounds more natural than gustar.
llevarse bien | to get along | phrase | yeh-BAHR-seh byehn | Me llevo muy bien con tu familia. | I get along really well with your family. | Llevarse bien / mal con + person
¿a qué te dedicas? | what do you do (for work)? | phrase | ah keh teh deh-DEE-kahs | ¿A qué te dedicas? —Soy enfermera. | "What do you do?" "I'm a nurse." | Soy + profession (no 'un / una')
no tengo ni idea | I have no idea | phrase | noh TEHN-goh nee ee-DEH-ah | No tengo ni idea de dónde está. | I have no idea where it is. | No tengo ni idea de + noun / question
poco a poco | little by little | phrase | POH-koh ah POH-koh | Poco a poco hablo mejor. | Little by little I'm speaking better. | Poco a poco + verb
lo que sea | whatever | phrase | loh keh SEH-ah | Lo que sea está bien. | Whatever is fine. | lo que + subjunctive = whatever …
¿qué onda? | what's up? | phrase | keh OHN-dah | ¿Qué onda? ¿Cómo te fue? | What's up? How did it go? | ¿Qué onda? (casual, Mexico) | Friends only — too casual for strangers.
¡qué padre! | how cool! | phrase | keh PAH-dreh | ¡Qué padre está tu casa! | Your house is so cool! | ¡Qué padre! (Mexico) · ¡Qué chévere! (Caribbean, Colombia)
ni modo | oh well | phrase | nee MOH-doh | Ya cerraron. Ni modo, vamos mañana. | They already closed. Oh well, we'll go tomorrow. | Ni modo (Mexico)

## fluent
aprovechar | to make the most of | verb | ah-proh-beh-CHAHR | Hay que aprovechar el buen tiempo. | We should make the most of the good weather. | Aprovechar + noun  ·  aprovechar para + infinitive
cumplir | to fulfill / to turn (an age) | verb | koom-PLEER | Cumplí mi promesa. | I kept my promise. | Cumplir + años = turn … years old
superar | to overcome / to get over | verb | soo-peh-RAHR | Superamos muchos obstáculos juntos. | We've overcome a lot of obstacles together. | Superar + noun
suponer | to suppose | verb | soo-poh-NEHR | Supongo que sí. | I suppose so. | Supongo que + sentence | Asumir means to take on (responsibility), not to suppose.
fingir | to pretend | verb | feen-HEER | No finjas que no me oíste. | Don't pretend you didn't hear me. | Fingir + infinitive / que + sentence | Pretender means to aim or intend — a false friend.
arrepentirse | to regret | verb | ah-rreh-pehn-TEER-seh | No me arrepiento de nada. | I don't regret anything. | Arrepentirse de + noun / infinitive
enterarse | to find out | verb | ehn-teh-RAHR-seh | Me enteré ayer de la noticia. | I found out about the news yesterday. | Enterarse de + noun
aguantar | to put up with / to hang on | verb | ah-gwahn-TAHR | Aguanta, ya casi llegamos. | Hang in there, we're almost there. | No aguanto + noun = I can't stand …
madrugar | to get up very early | verb | mah-droo-GAHR | Mañana hay que madrugar. | Tomorrow we have to get up early. | Hay que + infinitive = One has to … | la madrugada = the small hours of the morning
convivir | to live together | verb | kohn-bee-BEER | Convivir con alguien requiere paciencia. | Living with someone takes patience. | Convivir con + person
disfrutar | to enjoy | verb | dees-froo-TAHR | ¡Disfruta tu día! | Enjoy your day! | Disfrutar (de) + noun
agotado | exhausted / sold out | adjective | ah-goh-TAH-doh | Estoy agotada después del viaje. | I'm exhausted after the trip. | estar agotado = be exhausted (or sold out)
desafío | challenge | noun (m.) | deh-sah-FEE-oh | Aprender un idioma es un desafío. | Learning a language is a challenge. | ser un desafío = be a challenge
compromiso | engagement / commitment | noun (m.) | kohm-proh-MEE-soh | El anillo de compromiso es precioso. | The engagement ring is beautiful. | anillo de compromiso = engagement ring | 'Compromise' is usually acuerdo or término medio.
embarazada | pregnant | adjective | ehm-bah-rah-SAH-dah | Mi prima está embarazada. | My cousin is pregnant. | estar embarazada | False friend! Embarrassed = avergonzado/a, or me da vergüenza.
vergüenza | embarrassment / shame | noun (f.) | behr-GWEHN-sah | Me da vergüenza hablar en público. | I get embarrassed speaking in public. | Me da vergüenza + infinitive
éxito | success | noun (m.) | EHK-see-toh | ¡Mucho éxito en tu entrevista! | Good luck in your interview! | tener éxito = to be successful | False friend: exit = salida.
actualmente | currently | adverb | ahk-twahl-MEHN-teh | Actualmente trabajo desde casa. | Currently I work from home. | Actualmente + present tense | False friend: actually = en realidad.
en realidad | actually | phrase | ehn rreh-ah-lee-DAHD | En realidad, prefiero quedarme. | Actually, I'd rather stay. | En realidad, + sentence
sensible | sensitive | adjective | sehn-SEE-bleh | Es una persona muy sensible. | She's a very sensitive person. | ser sensible | False friend: sensible = sensato.
sin querer | by accident | phrase | seen keh-REHR | Lo rompí sin querer. | I broke it by accident. | verb + sin querer
a propósito | on purpose / by the way | phrase | ah proh-POH-see-toh | No lo hice a propósito. | I didn't do it on purpose. | A propósito, … = By the way, …
a pesar de | despite | phrase | ah peh-SAHR deh | A pesar de la lluvia, fuimos a la playa. | Despite the rain, we went to the beach. | A pesar de + noun  ·  a pesar de que + sentence
en cuanto | as soon as | conjunction | ehn KWAHN-toh | Te llamo en cuanto llegue. | I'll call you as soon as I get there. | En cuanto + subjunctive (for the future)
con tal de que | as long as | conjunction | kohn tahl deh keh | Voy, con tal de que volvamos temprano. | I'll go, as long as we come back early. | Con tal de que + subjunctive
si hubiera sabido | if I had known | phrase | see oo-BYEH-rah sah-BEE-doh | Si hubiera sabido, te habría llamado. | If I had known, I would have called you. | Si + hubiera + participle, habría + participle
hacer caso | to pay attention / to listen | phrase | ah-SEHR KAH-soh | Nunca me haces caso. | You never listen to me. | Hacer caso a + person
lo que pasa es que | the thing is | phrase | loh keh PAH-sah ehs keh | Lo que pasa es que no tengo tiempo. | The thing is, I don't have time. | Lo que pasa es que + sentence
no es para tanto | it's not a big deal | phrase | noh ehs PAH-rah TAHN-toh | Tranquilo, no es para tanto. | Relax, it's not a big deal. | No es para tanto
media naranja | soulmate / other half | idiom | MEH-dyah nah-RAHN-hah | Eres mi media naranja. | You're my other half. | ser la media naranja de alguien | Literally 'half orange'.
meter la pata | to put your foot in it | idiom | meh-TEHR lah PAH-tah | Metí la pata con tu mamá. | I really messed up with your mom. | Meter la pata con + person
costar un ojo de la cara | to cost an arm and a leg | idiom | kohs-TAHR oon OH-hoh deh lah KAH-rah | La boda va a costar un ojo de la cara. | The wedding is going to cost an arm and a leg. | Cuesta un ojo de la cara
ser pan comido | to be a piece of cake | idiom | sehr pahn koh-MEE-doh | Este examen es pan comido. | This exam is a piece of cake. | Es pan comido
tomar el pelo | to pull someone's leg | idiom | toh-MAHR ehl PEH-loh | ¿Me estás tomando el pelo? | Are you kidding me? | Tomarle el pelo a + person
echar una mano | to lend a hand | idiom | eh-CHAHR OO-nah MAH-noh | ¿Me echas una mano con la cena? | Can you give me a hand with dinner? | Echar una mano con + noun
estar en las nubes | to be daydreaming | idiom | ehs-TAHR ehn lahs NOO-behs | Perdón, estaba en las nubes. | Sorry, I was miles away. | Estar en las nubes
ponerse las pilas | to get your act together | idiom | poh-NEHR-seh lahs PEE-lahs | Me tengo que poner las pilas con el español. | I need to get serious about my Spanish. | Ponerse las pilas con + noun | Literally 'to put your batteries in'.
sacar de quicio | to drive someone crazy | idiom | sah-KAHR deh KEE-syoh | El ruido me saca de quicio. | The noise drives me up the wall. | Me saca de quicio + noun
dar en el clavo | to hit the nail on the head | idiom | dahr ehn ehl KLAH-boh | ¡Diste en el clavo! | You hit the nail on the head! | Dar en el clavo
estar de buenas | to be in a good mood | idiom | ehs-TAHR deh BWEH-nahs | Hoy estás de buenas. | You're in a good mood today. | Estar de buenas / de malas
hacerse el tonto | to play dumb | idiom | ah-SEHR-seh ehl TOHN-toh | No te hagas el tonto. | Don't play dumb. | Hacerse el / la + adjective = act …
más vale tarde que nunca | better late than never | idiom | mahs BAH-leh TAHR-deh keh NOON-kah | Llegaste tarde, pero más vale tarde que nunca. | You're late, but better late than never. | Más vale + A + que + B
al fin y al cabo | after all | phrase | ahl feen ee ahl KAH-boh | Al fin y al cabo, somos familia. | After all, we're family. | Al fin y al cabo, + sentence
"""


# ---------------------------------------------------------------------------
# Words with more than one meaning: the card shows every meaning, each with its own example.
#   spanish → (main English, optional (main example, translation) override, [extra meanings])
#   extra meaning = (English, part of speech or None, example, translation)
MEANINGS = {
    "querer": ("to want", None, [
        ("to love (someone)", None, "Te quiero mucho.", "I love you so much."),
    ]),
    "tiempo": ("time", None, [
        ("weather", None, "Hace buen tiempo hoy.", "The weather is nice today."),
    ]),
    "mañana": ("tomorrow", ("Nos vemos mañana.", "See you tomorrow."), [
        ("morning (la mañana)", "noun (f.)", "Corro por la mañana.", "I go running in the morning."),
    ]),
    "tarde": ("late", None, [
        ("afternoon (la tarde)", "noun (f.)", "Nos vemos esta tarde.", "See you this afternoon."),
    ]),
    "esperar": ("to hope", None, [
        ("to wait (for)", None, "Te espero en el coche.", "I'll wait for you in the car."),
    ]),
    "listo": ("ready (estar listo)", None, [
        ("smart, clever (ser listo)", None, "Tu hermana es muy lista.", "Your sister is very smart."),
    ]),
    "sueño": ("sleepiness (tener sueño)", None, [
        ("dream", None, "Anoche tuve un sueño muy raro.", "Last night I had a really strange dream."),
    ]),
    "rico": ("delicious, tasty", None, [
        ("rich", None, "Su familia es muy rica.", "His family is very rich."),
    ]),
    "cita": ("appointment", None, [
        ("date (romantic)", None, "Tenemos una cita el viernes.", "We have a date on Friday."),
    ]),
    "dejar": ("to let", None, [
        ("to leave (something somewhere)", None, "Dejé las llaves en casa.", "I left the keys at home."),
    ]),
    "tomar": ("to have (food or drink)", None, [
        ("to take", None, "Tomamos el autobús a las ocho.", "We take the bus at eight."),
    ]),
    "llevar": ("to take / to bring along", None, [
        ("to wear", None, "Llevas un vestido precioso.", "You're wearing a beautiful dress."),
    ]),
    "a propósito": ("on purpose", None, [
        ("by the way", None, "A propósito, ¿hablaste con tu mamá?", "By the way, did you talk to your mom?"),
    ]),
    "agotado": ("exhausted", None, [
        ("sold out", None, "Las entradas están agotadas.", "The tickets are sold out."),
    ]),
    "salud": ("health", None, [
        ("cheers! (a toast)", "interjection", "¡Salud! Por nosotros.", "Cheers! To us."),
        ("bless you! (after a sneeze)", "interjection", "—¡Achú! —¡Salud!", "\"Achoo!\" \"Bless you!\""),
    ]),
    # Second meanings the dictionary has and a beginner hears every day.
    "conocer": ("to know (people, places)", None, [
        ("to meet (for the first time)", None, "Nos conocimos en una fiesta.", "We met at a party."),
    ]),
    "que": ("that", None, [
        ("than (más … que)", None, "Mi hermano es más alto que yo.", "My brother is taller than me."),
    ]),
    "qué": ("what", None, [
        ("how … ! (¡Qué …!)", "adverb", "¡Qué bonito!", "How pretty!"),
    ]),
    "se": ("himself / herself / themselves", None, [
        ("each other", None, "Se quieren mucho.", "They love each other a lot."),
    ]),
    "no": ("no / not", None, [
        ("right? (at the end of a sentence)", "tag question", "Vienes mañana, ¿no?", "You're coming tomorrow, right?"),
    ]),
    "más": ("more", None, [
        ("else (¿algo más?)", None, "¿Algo más?", "Anything else?"),
    ]),
    "café": ("coffee", None, [
        ("brown (the color)", "adjective", "Tiene los ojos cafés.", "She has brown eyes."),
    ]),
    "grande": ("big", None, [
        ("old, grown-up (for people)", None, "Mi abuela ya está grande.", "My grandma is getting old."),
    ]),
    "traer": ("to bring", None, [
        ("to wear, to have on", None, "Traes una camisa muy bonita.", "You're wearing a really nice shirt."),
    ]),
    "volver": ("to come back", None, [
        ("to do again (volver a …)", None, "No lo vuelvo a hacer.", "I won't do it again."),
    ]),
    "pensar": ("to think", None, [
        ("to plan to (pensar + verb)", None, "Pienso ir al súper mañana.", "I'm planning to go to the store tomorrow."),
    ]),
    "recordar": ("to remember", None, [
        ("to remind", None, "Recuérdame llamar a mi mamá.", "Remind me to call my mom."),
    ]),
    "padre": ("father", None, [
        ("cool, great (Mexico)", "adjective", "¡Qué padre tu casa!", "Your house is so cool!"),
    ]),
    "hora": ("time (of day)", None, [
        ("hour", None, "La película dura dos horas.", "The movie lasts two hours."),
    ]),
    "ya": ("already", None, [
        ("no longer (ya no)", None, "Ya no vivo allí.", "I don't live there anymore."),
    ]),
    "ganar": ("to win", None, [
        ("to earn", None, "Gana mucho dinero.", "She earns a lot of money."),
    ]),
    "perder": ("to lose", ("Perdí mis llaves.", "I lost my keys."), [
        ("to miss (a bus, a flight)", None, "Perdí el autobús.", "I missed the bus."),
    ]),
    "probar": ("to try, to taste", None, [
        ("to try on (clothes)", None, "¿Me puedo probar esta camisa?", "Can I try on this shirt?"),
    ]),
    "creer": ("to think (in my opinion)", None, [
        ("to believe", None, "No te creo.", "I don't believe you."),
    ]),
    "cumplir": ("to keep (a promise)", None, [
        ("to turn (an age)", None, "Mañana cumplo treinta años.", "Tomorrow I turn thirty."),
    ]),
    "compromiso": ("engagement", None, [
        ("commitment", None, "Es un compromiso muy serio.", "It's a very serious commitment."),
    ]),
}
