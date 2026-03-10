# Käyttöliittymäparannukset Record Manager -pluginille

## 1. Sivutus (Pagination)
- Lisää sivutuskontrollit taulukkonäkymään
- Näytä montako tietuetta per sivu (10, 20, 50, 100)
- Näytä kokonaismäärä ja nykyinen sivu

## 2. "Yhdistä"-toiminnallisuus
- Toteuta "Yhdistä"-napin toiminnallisuus modalissa
- Lisää vahvistusikkuna ennen yhdistämistä
- Näytä onnistumis-/virheilmoitus toiminnon jälkeen
- Sulje modaali automaattisesti onnistuneen yhdistämisen jälkeen
- Päivitä päälistaus automaattisesti yhdistämisen jälkeen

## 3. Hakutoiminnallisuus ja suodattimet
- Lisää hakukenttä tietueiden suodattamiseen (tekijä, nimeke, kontrollinumero)
- Reaaliaikainen haku (live search)
- Suodatus kontrollinumero-identifikaattorin mukaan (FI-MELINDA, FI-BTJ, jne.)

## 4. Järjestys (Sorting)
- Tee taulukon sarakkeet klikattaviksi järjestystä varten
- Näytä nuolet järjestyssuunnan osoittamiseksi
- Tallenna järjestysvalinta selaimen muistiin

## 5. Lisätiedot ja yksityiskohdat
- Näytä valitun orphan-tietueen tiedot modalin yläosassa
- Lisää "Näytä MARC"-nappi molemmille tietueille
- Näytä vertailu orphan 773-kentän ja mahdollisen emojen välillä

## 6. Visuaaliset parannukset
- Lisää värikoodaus osumatarkkuudelle (vihreä >80%, keltainen 50-80%, punainen <50%)
- Korosta valittu rivi
- Paranna responsive-designia mobiililaitteille
- Lisää ikonit nappeihin (🔍 Etsi, 🔗 Yhdistä, ↻ Päivitä)

## 7. Lataustilojen parannukset
- Näytä edistymispalkki pitkissä operaatioissa
- Lisää skeleton loader -näkymä latauksen aikana
- Näytä arvioitu odotusaika suurille listoille

## 8. Virheenkäsittelyn parannukset
- Näytä selkeämmät virheilmoitukset
- Lisää "Yritä uudelleen" -nappi virheen jälkeen
- Logita virheet ja näytä tekninen info kehittäjille (console)

## 9. Käyttäjäpalaute (Feedback)
- Toast-ilmoitukset onnistuneista toiminnoista (ylä- tai alaosassa)
- Loading-indikaattori "Yhdistä"-napissa yhdistämisen aikana
- Disabloi napit toiminnon aikana

## 10. Tilastot ja yhteenveto
- Näytä tilastokortti sivun yläosassa (kokonaismäärä, käsiteltyjä, jne.)
- Graafit orphan-tietueiden jakaumasta
- Viimeisimmät yhdistetyt tietueet -lista

## 11. Massakäsittely (Batch operations)
- Valintaruudut tietueille
- "Valitse kaikki" -toiminto
- Mahdollisuus käsitellä useita tietueita kerralla

## 12. Vienti ja raportointi
- Vie lista CSV/Excel-muodossa
- Tulosta raportti
- Näytä yhteenveto yhdistämishistoriasta

## 13. Suorituskykyparannukset
- Virtualisointi pitkille listoille (älä renderöi kaikkia kerralla)
- Välimuistitus haettujen tietueiden osalta
- Debounce hakukentälle

## 14. Näppäinoikotiet
- ESC = Sulje modaali
- CTRL+F = Haku
- Enter = Yhdistä (modalissa)

## 15. Saavutettavuus (Accessibility)
- ARIA-labelit kaikille interaktiivisille elementeille
- Keyboard navigation -tuki
- Screen reader -yhteensopivuus
- Paremmat kontrastitasot

## 16. Lisätoiminnot
- "Päivitä lista" -nappi
- Automaattinen päivitys X sekunnin välein (toggle)
- Suosikit-merkintä usein käytetyille hakuehdoille
- Tuoreet vs. vanhat orphan-tietueet (aikaleima)

## 17. Modaalin parannukset
- Näytä komponentin 773-kenttä selkeästi
- Vertailunäkymä vierekäin (orphan vs. mahdollinen emo)
- Historia aiemmista yhdistämisyrityksistä

## Prioriteetti-järjestys toteutukselle

### Korkea prioriteetti (Core functionality)
1. "Yhdistä"-toiminnallisuus (#2)
2. Sivutus (#1)
3. Käyttäjäpalaute ja ilmoitukset (#9)
4. Virheenkäsittely (#8)

### Keskitaso prioriteetti (Usability)
5. Hakutoiminnot (#3)
6. Järjestys (#4)
7. Visuaaliset parannukset (#6)
8. Modaalin parannukset (#17)

### Matala prioriteetti (Nice to have)
9. Tilastot (#10)
10. Massakäsittely (#11)
11. Vienti ja raportointi (#12)
12. Lisätoiminnot (#16)
13. Näppäinoikotiet (#14)
14. Saavutettavuus (#15)
15. Suorituskykyparannukset (#13)
16. Lataustilojen parannukset (#7)
17. Lisätiedot (#5)
