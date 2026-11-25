# Kulka Sandbox 3D

Minimalistyczny sandbox fizyczny w Godot 4: jedna duża, błyszcząca kulka i otwarta ziemia — bez misji, przeszkód ani punktacji.

## Sterowanie

- **LPM na kulce + przeciąganie** — złap kulkę; puść przycisk, aby nadać jej pęd
- **PPM** — mocne popchnięcie w stronę kursora
- **R** — zresetuj pozycję

## Efekty i fizyka

- bliska, płynnie podążająca kamera
- fizyczna kula z odbiciem, tarciem i ciągłym wykrywaniem kolizji
- proceduralny shader ziemi z wariacją kolorów i detalem przypominającym trawę
- cienie, SSAO, bloom, metaliczny materiał kulki, świetlny ślad i iskry przy uderzeniach

Otwórz `project.godot` w Godot 4.3+ i uruchom scenę. Wydajność zależy od sprzętu i ustawień sterownika; efekty graficzne mogą zmniejszyć liczbę FPS.
