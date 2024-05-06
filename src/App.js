import './App.css';
import Breadcrumb from './Breadcrumb/Breadcrumb';
import { Route, Routes} from 'react-router-dom';
import Courses from './Screens/Courses';
import Contacts from './Screens/Contacts';
import Projects from './Screens/Projects';
import Research from './Screens/Research';
import Home from './Screens/Home';
import Footer from './Footer/Footer';

function App() {
  return (
    <>
        <div className="App">
            <Breadcrumb />
            
            <Routes>
              <Route path='/' Component = { Home }/>
              <Route path='/contacts' Component={ Contacts }/>
              <Route path='/courses' Component={ Courses }/>
              <Route path='/projects' Component={ Projects }/>
              <Route path='/research' Component={ Research }/>
            </Routes>

          <Footer />
        </div>
    </> 
  );
}

export default App;
