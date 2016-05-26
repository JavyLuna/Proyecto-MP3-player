import controlP5.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";

ControlP5 ui;
ScrollableList list;
Minim minim;
AudioPlayer song;
AudioMetaData meta;

FFT fft;
Client client;
Node node;
HighPassSP highpass;
LowPassSP lowpass;
BandPass bandpass;
LowPassFS   lpf;
Textlabel texto;
boolean si;

float[] buffer;
int ys = 25;
int yi = 15;
String autor="", titulo="";
boolean  mute=true;
boolean nada=false;
int Hpass;
int Lpass;
int Bpass;

void setup() {
  background(0);
  size(900, 300);
  minim = new Minim(this);
  ui = new ControlP5(this);
  Settings.Builder settings = Settings.settingsBuilder();

  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();
  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }

  ui.addButton("play").setPosition(0, 0).setSize(50, 50);
  ui.addButton("pause").setPosition(50, 0).setSize(50, 50);
  ui.addButton("stop").setPosition(100, 0).setSize(50, 50);
  ui.addButton("importFiles").setLabel("Importar archivos").setPosition(200, 0).setSize(80, 50);
  ui.addButton("atrasar").setValue(0).setPosition(0, 70).setSize(50, 50);
  ui.addButton("adelanto").setValue(0).setPosition(0, 130).setSize(50, 50);
  list = ui.addScrollableList("playlist").setPosition(0, 180).setSize(500, 300).setBarHeight(20).setItemHeight(20).setType(ScrollableList.LIST);
  ui.addButton("mute").setValue(0).setPosition(450, 120).setSize(50, 50);
  ui.addSlider("Hpass").setPosition(300, 0).setSize(20, 100).setRange(0, 3000).setValue(0).setNumberOfTickMarks(30);  
  ui.addSlider("Lpass").setPosition(350, 0).setSize(20, 100).setRange(3000, 20000).setValue(3000).setNumberOfTickMarks(30);  
  ui.addSlider("Bpass").setPosition(400, 0).setSize(20, 100).setRange(100, 1000).setValue(100).setNumberOfTickMarks(30);
  ui.getController("Hpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.getController("Lpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.getController("Bpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.addSlider("volumen").setRange(-40, 0).setValue(-20).setPosition(460, 0).setSize(10, 100);  
  loadFiles();
}
void draw() {
  if (song!= null) {
    highpass.setFreq(Hpass);
    lowpass.setFreq(Lpass);
    bandpass.setFreq(Bpass);
      stuff();
  }
  background(0);
  stroke(255);
  rect(500, 0, 10, 300);
  text("Titulo: " + titulo, 60, 80);
  text("Autor: " + autor, 60, 100);
  stuff();
}
public void play() {
  println("Play");
  meta = song.getMetaData();
  titulo = meta.title();
  autor = meta.author();
  song.play();
  fft = new FFT(song.bufferSize(), song.sampleRate());
}
public void pause() {
  println("Pause");
  song.pause();
}

public void stop() {
  println("Stop");
  song.close();
  song.pause();
  song.rewind();
}

public void atrasar() {
  println("Atrasar");
  song.skip(-500);
}
public void adelanto() {
  println("Adelanto");
  song.skip(500);
}

public void mute() {
  mute = !mute;
  if (mute) song.mute();
  else song.unmute();
}

void volumen(float volu) {
  float  volum = volu;
  if (volum==-40) {
    song.setGain(volum);
    song.setGain(-60);
  } else { 
    song.setGain(volum);
  }
}

/*void Hpass () {
 highpass = new HighPassSP(300, song.sampleRate());
 song.addEffect(highpass);
 }
 
 void Lpass() {
 lowpass = new LowPassSP(300, song.sampleRate());
 song.addEffect(lowpass);
 }
 
 void Bpass() {
 bandpass = new BandPass(300, 300, song.sampleRate());
 song.addEffect(bandpass);
 }*/

public void fileSelected(File selection) {
  if (selection == null) {
    println("Seleccion cancelada");
  } else {
    println("User selected " + selection.getAbsolutePath());
    song = minim.loadFile(selection.getAbsolutePath(), 1024);
    highpass = new HighPassSP(300, song.sampleRate());
    song.addEffect(highpass);
    lowpass = new LowPassSP(300, song.sampleRate());
    song.addEffect(lowpass);
    bandpass = new BandPass(300, 300, song.sampleRate());
    song.addEffect(bandpass);
  }
}

void importFiles() {
  // Selector de archivos
  JFileChooser jfc = new JFileChooser();
  // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  // Abre el dialogo de seleccion
  jfc.showOpenDialog(null);
  // Iteramos los archivos seleccionados
  for (File f : jfc.getSelectedFiles()) {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    Minim minim = new Minim(this);
    AudioPlayer song = minim.loadFile(f.getAbsolutePath());
    AudioMetaData meta = song.getMetaData();

    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();
      // Agregamos el archivo a la lista
      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}

void playlist(int n) {
  println(list.getItem(n));
  //println(list.getItem(n));
  if (song!=null) {
    song.pause();
  }
  Map<String, Object> value = (Map<String, Object>) list.getItem(n).get("value");
  println(value.get("path"));
  minim = new Minim(this);

  song = minim.loadFile((String)value.get("path"), 1024);
  fft = new FFT(song.bufferSize(), song.sampleRate());
      highpass = new HighPassSP(300, song.sampleRate());
    song.addEffect(highpass);
    lowpass = new LowPassSP(300, song.sampleRate());
    song.addEffect(lowpass);
    bandpass = new BandPass(300, 300, song.sampleRate());
    song.addEffect(bandpass);
  // calculate averages based on a miminum octave width of 22 Hz
  // split each octave into three bands
  fft.logAverages(22, 10);
  meta = song.getMetaData();
  if (!meta.title().equals("")) {
    texto.setText(meta.title()+"`\n"+meta.author());
    print("sale");
  } else {
    texto.setText(meta.fileName());
    print("entra");
  }
  //song = min.loadFile(selection.getAbsolutePath(),1024);
}
void loadFiles() {
  try {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for (SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}
void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}
void stuff() {
  if (!nada) {
    if (!(fft==null)) {
      fft.forward(song.mix);
      stroke(random(255), random(255), random(255));
      for (int i = 0; i < fft.specSize(); i++)
      {
        line(510, 300, 900, 300 - fft.getBand(i)*4);
      }
    }
    fill(255);
    try {
    }
    catch (Exception e) {
    }
    finally {
    }
  }
}