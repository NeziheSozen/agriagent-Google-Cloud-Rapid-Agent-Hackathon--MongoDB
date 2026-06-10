import re

file_path = "/Users/nezihes/Desktop/agrticulture agent/frontend/lib/app/l10n/translations.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

translations_to_add = {
    'es': {
        'spring_rainfall': 'Lluvia de Primavera',
        'summer_temperature': 'Temperatura de Verano',
        'forecast_abbr': 'P',
        'drought_days': 'Días de Sequía',
        'frost_days': 'Días de Helada',
        'season_forecast': 'Pronóstico de Temporada',
        'drought': 'Sequía',
        'predicted_rainfall': 'Lluvia Prevista',
        'avg_temperature': 'Temperatura Promedio',
        'analysis_notes': 'Notas de Análisis',
    },
    'nl': {
        'spring_rainfall': 'Lenteregenval',
        'summer_temperature': 'Zomertemperatuur',
        'forecast_abbr': 'V',
        'drought_days': 'Droogtedagen',
        'frost_days': 'Vorstdagen',
        'season_forecast': 'Seizoensvoorspelling',
        'drought': 'Droogte',
        'predicted_rainfall': 'Verwachte Regenval',
        'avg_temperature': 'Gemiddelde Temperatuur',
        'analysis_notes': 'Analyse Notities',
    },
    'it': {
        'spring_rainfall': 'Pioggia Primaverile',
        'summer_temperature': 'Temperatura Estiva',
        'forecast_abbr': 'P',
        'drought_days': 'Giorni di Siccità',
        'frost_days': 'Giorni di Gelo',
        'season_forecast': 'Previsioni Stagionali',
        'drought': 'Siccità',
        'predicted_rainfall': 'Pioggia Prevista',
        'avg_temperature': 'Temperatura Media',
        'analysis_notes': 'Note di Analisi',
    },
    'ja': {
        'spring_rainfall': '春の降水量',
        'summer_temperature': '夏の気温',
        'forecast_abbr': '予',
        'drought_days': '干ばつの日数',
        'frost_days': '霜の日数',
        'season_forecast': '季節の予報',
        'drought': '干ばつ',
        'predicted_rainfall': '予想降水量',
        'avg_temperature': '平均気温',
        'analysis_notes': '分析ノート',
    },
    'ko': {
        'spring_rainfall': '봄철 강수량',
        'summer_temperature': '여름철 온도',
        'forecast_abbr': '예',
        'drought_days': '가뭄 일수',
        'frost_days': '서리 일수',
        'season_forecast': '계절 예보',
        'drought': '가뭄',
        'predicted_rainfall': '예상 강수량',
        'avg_temperature': '평균 온도',
        'analysis_notes': '분석 노트',
    },
    'fr': {
        'spring_rainfall': 'Pluie de Printemps',
        'summer_temperature': 'Température Estivale',
        'forecast_abbr': 'P',
        'drought_days': 'Jours de Sécheresse',
        'frost_days': 'Jours de Gel',
        'season_forecast': 'Prévisions Saisonnières',
        'drought': 'Sécheresse',
        'predicted_rainfall': 'Pluie Prévue',
        'avg_temperature': 'Température Moyenne',
        'analysis_notes': 'Notes d\'Analyse',
    },
    'pt': {
        'spring_rainfall': 'Chuva de Primavera',
        'summer_temperature': 'Temperatura de Verão',
        'forecast_abbr': 'P',
        'drought_days': 'Dias de Seca',
        'frost_days': 'Dias de Geada',
        'season_forecast': 'Previsão Sazonal',
        'drought': 'Seca',
        'predicted_rainfall': 'Chuva Prevista',
        'avg_temperature': 'Temperatura Média',
        'analysis_notes': 'Notas de Análise',
    },
    'hi': {
        'spring_rainfall': 'वसंत ऋतु की बारिश',
        'summer_temperature': 'गर्मियों का तापमान',
        'forecast_abbr': 'पू',
        'drought_days': 'सूखे के दिन',
        'frost_days': 'पाला के दिन',
        'season_forecast': 'मौसम का पूर्वानुमान',
        'drought': 'सूखा',
        'predicted_rainfall': 'अनुमानित बारिश',
        'avg_temperature': 'औसत तापमान',
        'analysis_notes': 'विश्लेषण नोट्स',
    },
    'zh': {
        'spring_rainfall': '春季降雨量',
        'summer_temperature': '夏季温度',
        'forecast_abbr': '预',
        'drought_days': '干旱天数',
        'frost_days': '霜冻天数',
        'season_forecast': '季节预测',
        'drought': '干旱',
        'predicted_rainfall': '预计降雨量',
        'avg_temperature': '平均温度',
        'analysis_notes': '分析说明',
    }
}

for lang, trans_dict in translations_to_add.items():
    # Find the line: 'failed_to_load_climate': '...',
    pattern = re.compile(rf"([ \t]+'failed_to_load_climate': '[^']+',\n)")
    
    # Check if lang block exists by looking at surrounding code (but easiest is just doing a global replace with language context)
    # Wait, 'failed_to_load_climate' appears once per language block.
    # Let's find the specific block for each language by matching `'lang': {` and then replacing inside it.
    
    block_pattern = re.compile(rf"([ \t]+'{lang}': {{.*?}})", re.DOTALL)
    block_match = block_pattern.search(content)
    
    if block_match:
        block_text = block_match.group(1)
        
        # Prepare the new text
        new_lines = ""
        for key, val in trans_dict.items():
            new_lines += f"      '{key}': '{val}',\n"
            
        # Insert after failed_to_load_climate
        new_block_text = re.sub(
            r"([ \t]+'failed_to_load_climate': '[^']+',\n)",
            r"\1" + new_lines,
            block_text
        )
        
        content = content.replace(block_text, new_block_text)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done")
