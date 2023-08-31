Aedes aegypti Prediction Model
Este script foi desenvolvido para prever os focos de Aedes aegypti em Itajaí com base em variáveis climáticas, como temperatura e precipitação. Ele utiliza um modelo Random Forest para fazer essas previsões.

Como usar:
Instalação das Dependências:
Antes de executar o script, instale as bibliotecas necessárias. Você pode fazer isso usando pip:

Copy code
pip install pandas scikit-learn joblib
Prepare seus dados:

Coloque seus dados no mesmo formato do arquivo usado durante a modelagem (por exemplo, Itajai_2013_2021_a.xlsx).
Atualize o caminho do arquivo no script (data_path).
Execute o Script:
Execute o script Python. Isso treinará o modelo usando seus dados e salvará o modelo treinado em um arquivo .pkl.

Fazer previsões:
Com o modelo treinado, você pode carregá-lo e usar para fazer previsões em novos dados. A parte final do script demonstra como carregar o modelo e fazer previsões.

Notas:
O script atualmente agrupa os dados por estação do ano (primavera, verão, outono e inverno) e calcula as médias das variáveis para cada estação. Se desejar uma abordagem diferente, você precisará modificar o script de acordo.
O modelo foi otimizado para os dados de Itajaí e pode não ser aplicável diretamente a outros locais sem ajustes adicionais.