import re

with open('/Users/nezihes/Desktop/agrticulture agent/frontend/lib/app/l10n/translations.dart', 'r') as f:
    content = f.read()

new_keys = {
    'en': {
        'offline_title': 'Offline AI Assistant',
        'offline_desc_1': 'Download the Gemma 4 AI model to your device and continue using your agricultural assistant even without internet.',
        'offline_desc_2': 'Even if you lose internet connection in the field, you can still get instant farming advice and general agricultural guidance.',
        'model_info': 'Gemma 4 E2B  •  ~1 GB  •  Download once, use anytime',
        'downloading_progress': 'downloading...',
        'lets_go': 'Let\'s Go!',
        'skip_offline': 'No need, my internet is fine 👋',
        'download_later': 'You can also download it later from Settings.',
    },
    'tr': {
        'offline_title': 'Çevrimdışı Yapay Zeka Asistanı',
        'offline_desc_1': 'Gemma 4 yapay zeka modelini cihazınıza indirin ve internetiniz olmasa bile tarım asistanınızı kullanmaya devam edin.',
        'offline_desc_2': 'Tarlada internet bağlantınızı kaybetseniz bile anında tarımsal tavsiyeler ve genel danışmanlık almaya devam edebilirsiniz.',
        'model_info': 'Gemma 4 E2B  •  ~1 GB  •  Bir kere indir, hep kullan',
        'downloading_progress': 'indiriliyor...',
        'lets_go': 'Hadi Başlayalım!',
        'skip_offline': 'Gerek yok, internetim iyi 👋',
        'download_later': 'Daha sonra Ayarlar menüsünden de indirebilirsiniz.',
    }
}

# The translations dictionary in Dart looks like: 'en': { 'key': 'value', ... },
for lang in ['en', 'tr', 'nl', 'es', 'it', 'ja', 'ko', 'fr', 'pt', 'hi', 'zh']:
    # Determine which dictionary to use
    trans_dict = new_keys.get(lang, new_keys['en'])
    
    # Format the translation strings to inject
    inject_str = ""
    for k, v in trans_dict.items():
        v_escaped = v.replace("'", "\\'")
        inject_str += f"\n      '{k}': '{v_escaped}',"
    
    # We find the start of the language dictionary: e.g. 'en': {
    pattern = rf"('{lang}':\s*{{)"
    content = re.sub(pattern, r"\1" + inject_str, content, count=1)

with open('/Users/nezihes/Desktop/agrticulture agent/frontend/lib/app/l10n/translations.dart', 'w') as f:
    f.write(content)
