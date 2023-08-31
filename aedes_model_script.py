
import pandas as pd
import joblib
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split

# Função para determinar a estação do ano
def get_season(date):
    month = date.month
    if month in [9, 10, 11]:
        return 'Primavera'
    elif month in [12, 1, 2]:
        return 'Verão'
    elif month in [3, 4, 5]:
        return 'Outono'
    else:
        return 'Inverno'

# Importação e Preparação dos Dados
data_path = "path_to_your_data/Itajai_2013_2021_a.xlsx"
df = pd.read_excel(data_path)
df['Estacao'] = df['Data'].apply(get_season)
df_seasonal = df.groupby(['Ano', 'Estacao']).mean().reset_index()
df_seasonal.drop(columns=['Dia', 'Mes'], inplace=True)

# Divisão dos dados em treino e teste
X = df_seasonal.drop(columns=['Aedes', 'Data'])
y = df_seasonal['Aedes']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Treinamento do Modelo
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Salvar o modelo treinado
model_filename = "random_forest_model.pkl"
joblib.dump(model, model_filename)

# Carregar o modelo e fazer previsões
loaded_model = joblib.load(model_filename)
predictions = loaded_model.predict(X_test)

# Aqui, você pode continuar a processar as previsões conforme necessário
