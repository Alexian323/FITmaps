import express from 'express';
import bodyParser from 'body-parser';
import userRoutes from './routes/users.js'
import roomRoutes from './routes/room.js'
import profRoutes from './routes/prof.js'
import registerRoutes from './routes/register.js'
import historyRoutes from './routes/history.js'

const app = express();
const PORT = 5000

app.use(bodyParser.json());
app.use(express.urlencoded({ extended: true }));
app.use('/users', userRoutes);
app.use('/register', registerRoutes);
app.use('/room', roomRoutes);
app.use('/prof', profRoutes);
app.use('/history', historyRoutes);

app.get('/', (req, res) => {
    console.log('[GET ROUTE]');
    res.send('Register first');
})

app.listen(PORT, () => console.log(`Server running on port: http://localhost:${PORT}`));