function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
}

let running = true;

process.on('SIGINT', () => {
    console.log('Stopping due to "Ctrl+C"')
    running = false
})


async function run() {
    while(running) {
        const envValue = process.env.MY_ENV
        const name = process.env.APP_NAME
        console.log(`${name} alive`)
        console.log("env value", envValue)
        await sleep(5000)
    }
    console.log("Good bye!")
}

run()
