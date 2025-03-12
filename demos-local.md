# Localhost

These simple demos show the installation of the Ollama model engine, and then pulling a couple of different
models into this engine. I have tried these on a Windows PC with an Nvida 3080 10GB, and a 16GB Macbook Air M2.

## Installs

### Install - MacOS

```sh
brew install ollama
```

### Install - Windows

```sh
winget install Ollama.Ollama
```

## Execution

```sh
ollama serve &
```

### Llama

```sh
ollama run llama2

ollama stop llama2
```

### DeepSeek

```sh
ollama run deepseek-r1:14b

ollama stop deepseek-r1:14b
```

### Example Prompts

- What do you need to remember when participating in a tech Podcast?
- How would you run a successful Serverless Days Manchester conference?
