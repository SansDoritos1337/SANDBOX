# Kulka 3D — Fizyczny Plac Zabaw

Mała, grywalna scena 3D w Godot 4: sterujesz **jedną fizyczną kulką** po neonowej arenie. Rozpędzaj ją, skacz, używaj dopalacza i odbijaj się od bumperów, żeby zdobywać punkty.

## Uruchomienie

1. Otwórz `project.godot` w Godot 4.3 lub nowszym.
2. Naciśnij **F6/F5** albo przycisk Uruchom.

## Sterowanie

- **WASD** lub **strzałki** — rozpędzanie kulki
- **Spacja** — skok, gdy kulka dotyka podłoża
- **Shift** — dopalacz z krótkim czasem odnowienia
- **R** — powrót na środek areny

## Co jest w środku

- RigidBody3D z tarciem, sprężystością i ciągłym wykrywaniem kolizji
- siła przykładana przy spodzie kuli, dająca naturalne toczenie
- rampy, barierki i neonowe bumpery z fizycznym odbiciem oraz punktacją
- kamera podążająca za kulką i prosty HUD z prędkością

Cała arena jest tworzona skryptem `scripts/game.gd`; nie potrzeba dodatkowych assetów ani pluginów.
