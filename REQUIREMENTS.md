# Kravspecifikation: Skyddsrums-Kompassen

## 1. Syfte
Appens huvudsyfte är att i en nödsituation snabbt guida användaren till närmaste officiella skyddsrum med hjälp av realtidsdata från MSB och enhetens inbyggda sensorer.

## 2. Funktionella Krav
*   **Hämtning av data**: Appen ska hämta realtidsdata från MSB:s officiella ArcGIS-API (GeoJSON).
*   **Sökradie**: Appen ska som standard söka efter skyddsrum inom en radie av 5 km från användarens position.
*   **Automatisk målsökning**: Vid start ska appen automatiskt välja det geografiskt närmaste skyddsrummet som mål.
*   **Manuellt val**: Användaren ska kunna klicka på andra skyddsrum i en lista för att ändra mål. Valet ska då "låsas" så att appen inte hoppar tillbaka till ett annat skyddsrum automatiskt.
*   **Vägvisning**: Appen ska visa bäring (riktning) och distans (meter) till det valda målet i realtid.
*   **Filtrering av data**: Appen ska filtrera bort skyddsrum som är otillgängliga (t.ex. stängda, fullt) och inte visas i listan.

## 3. Tekniska Krav & Sensorer
*   **GPS/Positionering**:
    *   Ska kräva och hantera `ACCESS_FINE_LOCATION`.
    *   Ska uppdatera positionen i realtid (högsta noggrannhet: `bestForNavigation`).
    *   Ska använda GPS-kurs (heading) för riktning när användaren rör sig (över 3.6 km/h) för maximal precision.
*   **Magnetometer**:
    *   Ska användas för att visa riktning när användaren står stilla.
    *   Ska inkludera ett mjukvarufilter (Low-pass filter) för att minska "darrningar" i kompassnålen.
*   **Kalibrering**:
    *   En visuell guide för hårdvarukalibrering (figur 8-mönster) ska finnas tillgänglig.
*   **Plattformar**: initialt stöd för Android och iOS (mobilt).

## 4. Användargränssnitt (UI)
*   **Dashboard**: En tydlig visuell kompassnål som pekar mot målet.
*   **Karta**: En karta som visar användarens position och valt mål.
*   **Statusindikatorer**: Visa tydligt om appen använder GPS-kurs eller Magnetisk kurs.
*   **Skyddsrumsdetaljer**: Visa adress, avstånd och antal platser (kapacitet) för varje skyddsrum.
*   **Designsystem**: Modern Material 3-design med stöd för Dark Mode (för att spara batteri vid nödsituationer).

## 5. Säkerhet & Integritet
*   **Datahantering**: Ingen positionsdata ska sparas eller skickas till externa servrar (förutom vid själva sökningen mot MSB:s API).
*   **Offline-läge**: Möjlighet att cache-lagra närområdets skyddsrum lokalt om internetuppkopplingen går ner.

## 6. Framtida Utveckling
*   **WearOS/Smartwatch**: Implementera en förenklad version för klockor.
*   **Språkalternativ**: Lägg till stöd för minoritetsspråk samt de vanligast talade språken i Sverige. 
*   **Push-notiser**: Integrera med VMA (Viktigt Meddelande till Allmänheten).
