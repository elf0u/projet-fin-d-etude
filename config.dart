class AppConfig {
  static const String serverIp = '192.168.1.6';
  //static const String serverIp = '172.16.29.143';
  static const String baseUrl = 'http://$serverIp/iot_backend';

  static const String getChartData = '$baseUrl/get_chart_data.php';
  static const String getPrediction = '$baseUrl/get_prediction.php';

  static const String mqttBrokerIp = serverIp;
  static const int mqttPort = 1883;

  static const String signup = '$baseUrl/signup.php';
  static const String signin = '$baseUrl/signin.php';
}