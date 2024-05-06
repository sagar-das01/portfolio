
import '../App.css';
import { Link } from 'react-router-dom';

function Breadcrumb(){
    return (
        <div className='bc-container'>
            <div className="bc">
                <Link className="link" to="/home">Home</Link>
                <Link to="/contacts">Contacts</Link>
                <Link to="/projects">Projects</Link>
                <Link to="/research">Research</Link>
                <Link to="/courses">Courses</Link>
            </div>
        </div>
    );
}

export default Breadcrumb;