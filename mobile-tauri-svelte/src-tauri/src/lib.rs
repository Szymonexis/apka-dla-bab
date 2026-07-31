// Cała logika aplikacji żyje we frontendzie (Svelte). Rust to cienka powłoka:
// webview + pluginy (HTTP bez CORS-a i ograniczeń cleartext webview'a,
// lokalne powiadomienia z harmonogramem na Androidzie).

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_notification::init())
        .run(tauri::generate_context!())
        .expect("nie udało się uruchomić aplikacji");
}
