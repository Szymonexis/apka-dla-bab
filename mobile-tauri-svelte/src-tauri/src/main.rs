// Bez dodatkowego okna konsoli na Windowsie w wersji release.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    ogarniaczka_lib::run()
}
